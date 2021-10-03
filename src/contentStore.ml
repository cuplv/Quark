open Scylla
open Scylla.Protocol

open Util

let ks_query = Printf.sprintf
  "create keyspace if not exists content
   with replication = {
   'class':'SimpleStrategy',
   'replication_factor':1};"

let create_query s = Printf.sprintf
  "create table if not exists content.%s(
   key blob,
   value blob,
   primary key (key))"
  s

let insert_query s = Printf.sprintf
  "insert into content.%s(
   key,
   value)
   VALUES (?,?)"
  s

let select_query s = Printf.sprintf
  "select value from content.%s where key = ?"
  s

module Make (Stored : Content.STORABLE) = struct
  type handle = Util.table_handle
  let init s conn =
    let* _ = query conn ~query:ks_query () in
    let* _ = query conn ~query:(create_query s) () in
    Ok { store_name = s; connection = conn }
    
  let put t v =
    let hash = Stored.hash v in
    let kb = Blob (big_of_string hash) in
    let vb = Blob (Stored.to_big v) in
    let _ = query
              t.connection
              ~query:(insert_query t.store_name)
              ~values:[|kb;vb|]
              ()
            |> Result.get_ok in
    hash
  let get t hash =
    let kb = Blob (big_of_string hash) in
    let v = query
              t.connection
              ~query:(select_query t.store_name)
              ~values:[|kb|]
              ()
            |> Result.get_ok
    in
    if Array.length v.values > 0
    then Some (Stored.from_big (get_blob v.values.(0).(0)))
    else None
end
