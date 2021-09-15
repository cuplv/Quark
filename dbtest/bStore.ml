open Scylla
open Scylla.Protocol

open Util

let ks_query = Printf.sprintf
  "create keyspace if not exists bstore
   with replication = {
   'class':'SimpleStrategy',
   'replication_factor':1};"

let create_bstore_query s = Printf.sprintf
  "create table if not exists bstore.%s_branches(
   name blob,
   latest blob,
   primary key (name))"
  s

let create_lcastore_query s = Printf.sprintf
  "create table if not exists bstore.%s_lcas(
   key blob,
   lca blob,
   primary key (key))"
  s

let list_query s = Printf.sprintf
  "select name from bstore.%s_branches"
  s

(* INSERT updates a row if the primary keys match *)
let upsert_branch_query s = Printf.sprintf
  "insert into bstore.%s_branches(
   name,
   latest)
   VALUES (?,?)"
  s

let get_latest_query s = Printf.sprintf
  "select latest from bstore.%s_branches where name = ?"
  s

let upsert_lca_query s = Printf.sprintf
  "insert into bstore.%s_lcas(
   key,
   lca)
   VALUES (?,?)"
  s

let get_lca_query s = Printf.sprintf
  "select lca from bstore.%s_lcas where key = ?"
  s

type branch = string

let get_branch_name v =
  Bigstringaf.to_string (get_value v.(0))

let branch_pair_key b1 b2 =
  let (h1,h2) = if b1 < b2
                then (Digest.string b1, Digest.string b2)
                else (Digest.string b2, Digest.string b1) in
  Digest.string (h1 ^ h2)

module Store = struct
  type t = { store_name : string; connection : conn }
  let init s conn =
    let r1 = query conn ~query:ks_query () in
    let r2 = Result.bind r1
               (fun _ -> query conn ~query:(create_bstore_query s) ())
    in
    let r3 = Result.bind r2
               (fun _ -> query conn ~query:(create_lcastore_query s) ())
    in
    Result.map (fun _ -> {store_name = s; connection = conn}) r3
  let list_branches t =
    let r = query
              t.connection
              ~query:(list_query t.store_name)
              ()
          |> Result.get_ok
    in
    Array.map get_branch_name r.values
  let update_branch t n v =
    let nb = Blob (big_of_string n) in
    let vb = Blob (big_of_string v) in
    let r = query
              t.connection
              ~query:(upsert_branch_query t.store_name)
              ~values:[|nb;vb|]
              ()
    in
    Result.map (fun _ -> n) r
  let get_latest : t -> branch -> (string, string) result = fun t n ->
    let nb = Blob (big_of_string n) in
    let r = query
              t.connection
              ~query:(get_latest_query t.store_name)
              ~values:[|nb|]
              ()
    in
    Result.map (fun v -> Bigstringaf.to_string (get_value v.values.(0).(0))) r
  let update_lca : t -> branch -> branch -> string -> (unit, string) result
    = fun t n1 n2 v ->
    let kb = Blob (big_of_string (branch_pair_key n1 n2)) in
    let vb = Blob (big_of_string v) in
    let r = query
              t.connection
              ~query:(upsert_lca_query t.store_name)
              ~values:[|kb;vb|]
              ()
    in
    Result.map (fun _ -> ()) r
  let get_lca : t -> branch -> branch -> (string, string) result
    = fun t n1 n2 ->
    let kb = Blob (big_of_string (branch_pair_key n1 n2)) in
    let r = query
              t.connection
              ~query:(get_lca_query t.store_name)
              ~values:[|kb|]
              ()
    in
    Result.map
      (fun v -> Bigstringaf.to_string (get_value v.values.(0).(0)))
      r
  let fork : t -> branch -> branch -> (string, string) result
    = fun t n1 n2 ->
    let r = Result.bind (get_latest t n1)       (fun v ->
            Result.bind (update_branch t n2 v)  (fun _ ->
                         update_lca t n1 n2 v))
    in
    Result.map (fun _ -> n2) r
  let pull : mergefun -> t -> branch -> branch -> (unit, string) result
    = fun merge t from_b into_b ->
    Result.bind (get_latest t into_b)     (fun into_v ->
    Result.bind (get_latest t from_b)     (fun from_v ->
    Result.bind (get_lca t from_b into_b) (fun lca_v ->
    if lca_v = from_v
    then
      (* Case 1: There is nothing to update *)
      Ok ()
    else if lca_v = into_v
    then
      (* Case 2: Fast-forward to from_b's value *)
      Result.bind (update_branch t into_b from_v)     (fun _ ->
      Result.bind (update_lca t from_b into_b from_v) (fun _ ->
      Ok () ))
    else
      (* Case 3: Perform 3-way merge *)
      (* Get merged value *)
      Result.bind (merge lca_v into_v from_v)      (fun m_v ->
      (* Update into-branch to merged value *)
      Result.bind (update_branch t into_b m_v)     (fun _ ->
      (* Update lca to from-branch's value *)
      Result.bind (update_lca t from_b into_b from_v) (fun _ ->
  
      Ok () ))) )))
end
