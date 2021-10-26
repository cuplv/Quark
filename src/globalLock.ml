open Scylla
open Scylla.Protocol
open Util

let create_lock_table_query s = Printf.sprintf
  "create table if not exists tag.%s_lock(
     id int,
     branch text,
     primary key (id))"
  s

(*
 * This is the CAS (LWT) query.
 *)
let insert_lock_query s = Printf.sprintf
  "insert into tag.%s_lock(id, branch) 
   VALUES (?,?) if not exists"
  s

let delete_lock_query s = Printf.sprintf
  "delete from tag.%s_lock where id = ?"
  s

let update_lock_query s = Printf.sprintf
  "update tag.%s_lock set branch = ?
    where id = ? if id = ?"
  s

let debug_query s = Printf.sprintf
  "select id, branch from tag.%s_lock"
  s


let init s conn =
  let* _ = query conn ~query:(create_lock_table_query s) () in
  Ok ()


let try_acquire db b = 
  let res = query db.System.connection
              ~query:(insert_lock_query db.System.store_name)
              ~values:[|Int (System.global_lock_id); 
                        Varchar (big_of_string b)|] 
              ~consistency: Quorom () in
  (*let res = query db.System.connection
            ~query:(update_lock_query db.System.store_name)
            ~values:[| Blob (big_of_string b); 
                       Int (System.global_lock_id); 
                       (*Blob (big_of_string System.global_branch)*)|] 
            ~consistency: db.System.consistency
            ~serial_consistency: Scylla.Protocol.Serial () in*)
  begin
    match res with
    | Ok {values;_} -> (match values.(0).(0) with 
                          | Boolean b -> b
                          | _ -> failwith "Unexpected outcome \
                                of conditional insert")
    | Error s -> failwith s
  end


let release db b = 
  let _ = ignore b in
  let res = query db.System.connection
              ~query:(delete_lock_query db.System.store_name)
              ~values:[|Int (System.global_lock_id)|] 
              ~consistency: Quorom () in
  (*let res = query db.System.connection
            ~query:(update_lock_query db.System.store_name)
            ~values:[| Blob (big_of_string System.global_branch); 
                       Int (System.global_lock_id); 
                       (*Blob (big_of_string b)*) |]
            ~consistency: db.System.consistency
            ~serial_consistency: Scylla.Protocol.Serial () in*)
  begin
    match res with
    | Ok _ -> true
    | Error s -> failwith s
  end
