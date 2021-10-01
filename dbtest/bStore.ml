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
    Array.to_list (Array.map get_branch_name r.values)
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
  let get_other_lcas : t -> branch -> branch -> (branch * version * version) list
    = fun t b1 b2 ->
    (* Get other branches *)
    let other_bs = List.filter
                     (fun b -> b <> b1 && b <> b2)
                     (list_branches t)
    in
    (* Get tuples (other_branch, lca_with_from, lca_with_into) *)
    List.map
      (fun b -> (b,
                 get_lca t b1 b |> Result.get_ok,
                 get_lca t b2 b |> Result.get_ok))
      other_bs
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
    let _ = List.iter
              (fun (b,lca,_) -> update_lca t b new_branch lca
                                |> Result.get_ok)
              (get_other_lcas t old_branch new_branch)
    in
    Ok new_version
  let pull : mergefun -> t -> branch -> branch -> ((unit, branch) result, string) result
    = fun mergefun t from_b into_b ->
    let* into_v = get_head t into_b in
    let* from_v = get_head t from_b in
    let* lca_v = get_lca t from_b into_b in
    if lca_v = from_v
    then
      (* There is nothing to update. *)
      Ok (Ok ())
    else
      let other_lcas = get_other_lcas t from_b into_b in
      (* Find any violation of the "no concurrent LCAs for other
         branches" requirement. *)
      let r = List.find_opt
                (fun (_,from_lca,into_lca) ->
                  Version.Graph.is_concurrent
                     t.version_graph
                     from_lca
                     into_lca)
                other_lcas
      in
      match r with
      | None ->
         (* No violations of the requirement, proceeding with update. *)

         (* Create new version using either fastfwd or merge. *)
         let new_v = if lca_v = into_v
                     then Version.fastfwd from_v into_v
                     else Version.merge mergefun lca_v from_v into_v
                          |> Result.get_ok
         in
         (* Update head of into_b to the new version. *)
         let* _ = update_head t new_v in
         (* Update LCA between from_b and into_b, using from_b's head
            as LCA version. *)
         let* _ = update_lca t from_b into_b from_v in
         (* Update the other branches' LCAs for into_b. *)
         let _ = List.map
                   (fun (other_b,from_lca,into_lca) ->
                     if Version.Graph.is_ancestor
                          t.version_graph
                          into_lca
                          from_lca
                     then update_lca t into_b other_b from_lca
                          |> Result.get_ok
                     else ())
                   other_lcas
         in
         (* Update was successful. *)
         Ok (Ok ())
      | Some (b,_,_) ->
         (* No database errors, but update was blocked due to this other branch. *)
         Ok (Error b)
end
