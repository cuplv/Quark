open Scylla
open Scylla.Protocol

open Util

type branch = Types.branch
type handle = table_handle

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

(** Put branches in canonical order so that their entry in the LCA map
   can be found. *)
let order_branches : branch -> branch -> branch * branch =
  fun b1 b2 -> if b1 > b2 then (b1,b2) else (b2,b1)

let init s conn =
  let* _ = query conn ~query:(create_lcastore_query s) () in
  Ok { store_name = s; connection = conn }

let set t n1 n2 lca =
  let (b1,b2) = order_branches n1 n2 in
  let _ = query
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
        |> Result.get_ok
    in
    ()

let get t n1 n2 =
  let (b1,b2) = order_branches n1 n2 in
  let r = query
            t.connection
            ~query:(get_lca_query t.store_name)
            ~values:[|
              Blob (big_of_string b1);
              Blob (big_of_string b2)
            |]
            ()
        |> Result.get_ok
  in
  if Array.length r.values > 0
  then Some (Version.of_row r.values.(0))
  else None
