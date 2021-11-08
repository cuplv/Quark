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
     vector_clock blob,
     timestamp blob,
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
     content_id,
     vector_clock,
     timestamp)
   VALUES (?,?,?,?,?)"
  s

let get_head_query s = Printf.sprintf
  "select branch, version_num, content_id, vector_clock, timestamp
   from tag.%s_head
   where branch = ?"
  s

let init s conn =
  let* _ = query conn ~query:(create_headmap_query s) () in
  Ok ()

let list_branches db =
    let r = query
              db.connection
              ~query:(list_query db.store_name)
              ~consistency: db.consistency
              ()
          |> Result.get_ok
    in
    Array.to_list (Array.map (fun row -> get_string row.(0)) r.values)

let set db v =
  let _ = query
            db.connection
            ~query:(upsert_head_query db.store_name)
            ~values:(Version.to_row v)
            ~consistency: db.consistency
            ()
          |> Result.get_ok
  in
  ()

let get db name =
  let r = query
            db.connection
            ~query:(get_head_query db.store_name)
            ~values:[| Blob (big_of_string name) |]
            ~consistency: db.consistency
            ()
          |> Result.get_ok
  in
  if Array.length r.values > 0
  then Some (Version.of_row r.values.(0))
  else None
