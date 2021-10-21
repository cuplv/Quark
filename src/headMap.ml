open Scylla
open Scylla.Protocol

open Util
open System

type branch = Types.branch

let create_headmap_query s = Printf.sprintf
  "create table if not exists tag.%s_head(
     branch blob,
     version_num int,
     content_id blob,
     primary key (branch))"
  s

let list_query s = Printf.sprintf
  "select branch from tag.%s_head"
  s

(* INSERT updates a row if the primary keys match *)
let upsert_head_query s = Printf.sprintf
  "insert into tag.%s_head(
     branch,
     version_num,
     content_id)
   VALUES (?,?,?)"
  s

let get_head_query s = Printf.sprintf
  "select branch, version_num, content_id
   from tag.%s_head
   where branch = ?"
  s

let init s conn =
  let* _ = query conn ~query:(create_headmap_query s) () in
  Ok ()

let list_branches t =
    let r = query
              t.connection
              ~query:(list_query t.store_name)
              ()
          |> Result.get_ok
    in
    Array.to_list (Array.map (fun row -> get_string row.(0)) r.values)

let set t v =
  let _ = query
            t.connection
            ~query:(upsert_head_query t.store_name)
            ~values:(Version.to_row v)
            ()
          |> Result.get_ok
  in
  ()

let get t name =
  let r = query
            t.connection
            ~query:(get_head_query t.store_name)
            ~values:[| Blob (big_of_string name) |]
            ()
          |> Result.get_ok
  in
  if Array.length r.values > 0
  then Some (Version.of_row r.values.(0))
  else None
