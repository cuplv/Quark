open Scylla
open Scylla.Protocol

open Util
open System

type branch = Types.branch

let create_lcastore_query s = Printf.sprintf
  "create table if not exists tag.%s_lca(
     branch1 blob,
     branch2 blob,
     lca_branch blob,
     lca_version_num int,
     lca_content_id blob,
     lca_vector_clock blob,
     lca_timestamp blob,
     primary key (
       branch1,
       branch2))"
  s

let upsert_lca_query s = Printf.sprintf
  "insert into tag.%s_lca(
     branch1,
     branch2,
     lca_branch,
     lca_version_num,
     lca_content_id,
     lca_vector_clock,
     lca_timestamp)
   VALUES (?,?,?,?,?,?,?)"
  s

let get_lca_query s = Printf.sprintf
  "select lca_branch, lca_version_num, lca_content_id,
      lca_vector_clock, lca_timestamp from tag.%s_lca
   where branch1 = ? and branch2 = ?"
  s

let debug_query s = Printf.sprintf
  "select branch1, branch2, lca_branch, lca_version_num
   from tag.%s_lca"
  s

(** Put branches in canonical order so that their entry in the LCA map
   can be found. *)
let order_branches : branch -> branch -> branch * branch =
  fun b1 b2 -> if b1 > b2 then (b1,b2) else (b2,b1)

let init s conn =
  let* _ = query conn ~query:(create_lcastore_query s) () in
  Ok ()

let set db n1 n2 lca =
  let (b1,b2) = order_branches n1 n2 in
  let _ = query
            db.connection
            ~query:(upsert_lca_query db.store_name)
            ~consistency: db.consistency
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

let get db n1 n2 =
  let (b1,b2) = order_branches n1 n2 in
  let r = query
            db.connection
            ~query:(get_lca_query db.store_name)
            ~values:[|
              Blob (big_of_string b1);
              Blob (big_of_string b2)
            |]
            ~consistency: db.consistency
            ()
        |> Result.get_ok
  in
  if Array.length r.values > 0
  then Some (Version.of_row r.values.(0))
  else None

let debug_dump db =
  let r = query
            db.connection
            ~query:(debug_query db.store_name)
            ()
          |> Result.get_ok
  in
  let () = Printf.printf "LCA Map: (b1, b2) <- lca)\n" in
  Array.iter
    (fun row ->
      let b1 = get_string row.(0) in
      let b2 = get_string row.(1) in
      let lca_b = get_string row.(2) in
      let lca_vn = get_int row.(3) in

      Printf.printf
        "(%s, %s) <- %s:%d\n"
        b1
        b2
        lca_b
        lca_vn)
    r.values
