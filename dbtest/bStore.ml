open Scylla
open Scylla.Protocol

open Util

type version = Version.t

let ks_query = Printf.sprintf
  "create keyspace if not exists bstore
   with replication = {
   'class':'SimpleStrategy',
   'replication_factor':1};"

let create_bstore_query s = Printf.sprintf
  "create table if not exists bstore.%s_head(
     branch blob,
     version_num int,
     content_id blob,
     primary key (branch))"
  s

let create_lcastore_query s = Printf.sprintf
  "create table if not exists bstore.%s_lca(
     branch1 blob,
     branch2 blob,
     lca_branch blob,
     lca_version_num int,
     lca_content_id blob,
     primary key (
       branch1,
       branch2))"
  s

let list_query s = Printf.sprintf
  "select branch from bstore.%s_head"
  s

(* INSERT updates a row if the primary keys match *)
let upsert_branch_query s = Printf.sprintf
  "insert into bstore.%s_head(
     branch,
     version_num,
     content_id)
   VALUES (?,?,?)"
  s

let get_head_query s = Printf.sprintf
  "select branch, version_num, content_id
   from bstore.%s_head
   where branch = ?"
  s

let upsert_lca_query s = Printf.sprintf
  "insert into bstore.%s_lca(
     branch1,
     branch2,
     lca_branch,
     lca_version_num,
     lca_content_id)
   VALUES (?,?,?,?,?)"
  s

let get_lca_query s = Printf.sprintf
  "select lca_branch, lca_version_num, lca_content_id from bstore.%s_lca
   where branch1 = ? and branch2 = ?"
  s

type branch = string

let get_branch_name v =
  Bigstringaf.to_string (get_blob v.(0))

let order_branches : branch -> branch -> branch * branch =
  fun b1 b2 -> if b1 > b2 then (b1,b2) else (b2,b1)

let branch_pair_key b1 b2 =
  let (h1,h2) = if b1 < b2
                then (Digest.string b1, Digest.string b2)
                else (Digest.string b2, Digest.string b1) in
  Digest.string (h1 ^ h2)

module Store = struct
  type t =
    { store_name : string;
      connection : conn;
      version_graph : Version.Graph.handle
    }
  let init s conn =
    let* _ = query conn ~query:ks_query () in
    let* graph = Version.Graph.init s conn in
    let* _ = query conn ~query:(create_bstore_query s) () in
    let* _ = query conn ~query:(create_lcastore_query s) () in
    Ok
      { store_name = s;
        connection = conn;
        version_graph = graph
      }
  let list_branches t =
    let r = query
              t.connection
              ~query:(list_query t.store_name)
              ()
          |> Result.get_ok
    in
    Array.map get_branch_name r.values
  let update_head : t -> version -> (unit, string) result =
    fun t v ->
    let* _ = query
               t.connection
               ~query:(upsert_branch_query t.store_name)
               ~values:(Version.to_row v)
               ()
    in
    Ok ()
  let get_head_opt : t -> branch -> (version option, string) result =
    fun t b ->
    let* r = query
               t.connection
               ~query:(get_head_query t.store_name)
               ~values:[| Blob (big_of_string b) |]
               ()
    in
    if Array.length r.values > 0
    then Ok (Some (Version.of_row r.values.(0)))
    else Ok None
  let get_head : t -> branch -> (version, string) result =
    fun t b ->
    let* o = get_head_opt t b in
    Ok (Option.get o)
  let update_lca : t -> branch -> branch -> version -> (unit, string) result
    = fun t n1 n2 lca ->
    let (b1,b2) = order_branches n1 n2 in
    let* _ = query
               t.connection
               ~query:(upsert_lca_query t.store_name)
               ~values:(Array.append
                          (* Branches *)
                          [| Blob (big_of_string b1);
                             Blob (big_of_string b2)
                          |]
                          (* LCA version *)
                          (Version.to_row lca))
               ()
    in
    Ok ()
  let get_lca : t -> branch -> branch -> (version, string) result
    = fun t n1 n2 ->
    let (b1,b2) = order_branches n1 n2 in
    let* r = query
               t.connection
               ~query:(get_lca_query t.store_name)
               ~values:[|
                 Blob (big_of_string b1);
                 Blob (big_of_string b2)
               |]
               ()
    in
    Ok (Version.of_row r.values.(0))
  let fork : t -> branch -> branch -> (version, string) result
    = fun t old_branch new_branch ->
    let* old_version = get_head t old_branch in
    let new_version = Version.fork new_branch old_version
    in
    let* _ = Version.Graph.add_version
               t.version_graph
               new_version
               [old_version]
    in
    let* _ = update_head t new_version in
    let* _ = update_lca t old_branch new_branch old_version in
    Ok new_version
  let pull : mergefun -> t -> branch -> branch -> (unit, string) result
    = fun mergefun t from_b into_b ->
    let* into_v = get_head t into_b in
    let* from_v = get_head t from_b in
    let* lca_v = get_lca t from_b into_b in
    if lca_v = from_v
    then
      (* Case 1: There is nothing to update *)
      Ok ()
    else if lca_v = into_v
    then
      (* Case 2: Fast-forward to match from_b's version *)
      let new_version = Version.fastfwd from_v into_v in
      (* New version gets both heads as parents *)
      let* _ = Version.Graph.add_version
                 t.version_graph
                 new_version
                 [from_v; into_v]
      in
      let* _ = update_head t new_version in
      let* _ = update_lca t from_b into_b from_v in
      Ok ()
    else
      (* Case 3: Perform 3-way merge *)
      (* Get merged value *)
      let* new_version = Version.merge mergefun lca_v from_v into_v in
      (* New version gets both heads as parents *)
      let* _ = Version.Graph.add_version
                 t.version_graph
                 new_version
                 [from_v; into_v]
      in
      let* _ = update_head t new_version in
      (* Update lca to from-branch's value *)
      let* _ = update_lca t from_b into_b from_v in
      Ok ()
end
