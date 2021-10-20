open Scylla
open Scylla.Protocol (* Defines Scylla store value types *)

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

let select_query s = 
  let qry = Printf.sprintf 
      "select value from content.%s where key = ?" s in
  qry

module Make (Stored : Content.SERIALIZABLE) = struct
  type handle = Util.table_handle

  let to_json_string = Irmin.Type.to_json_string Stored.t
  let of_json_string = Irmin.Type.of_json_string Stored.t


  let init s conn =
    let* _ = query conn ~query:ks_query () in
    let* _ = query conn ~query:(create_query s) () in
    Ok { store_name = s; connection = conn }
    
  let put t v =
    let json = big_of_string @@ to_json_string v in
    let hash = Hash.digest_big_string json in
    let kb = Blob (Hash.big_string hash) in
    (* let _ = Printf.printf "hash: %s\n" @@ Hash.string hash in
    let _ = Printf.printf "putting %s\n" @@ Scylla.show_value kb in *)
    let vb = Blob json in
    let _ = query
              t.connection
              ~query:(insert_query t.store_name)
              ~values:[|kb;vb|]
              ()
            |> Result.get_ok in
    hash

  let get t hash =
    let kb = Blob (Hash.big_string hash) in
    (*let _ = Printf.printf "hash: %s\n" @@ Hash.string hash in
    let _ = Printf.printf "key:%s\n" @@ Scylla.show_value kb in*)
    let v = query
              t.connection
              ~query:(select_query t.store_name)
              ~values:[|kb|]
              ()
            |> Result.get_ok
    in
    if Array.length v.values > 0
    then 
      let json_str = get_string v.values.(0).(0) in
      match of_json_string json_str with
        | Ok v -> Some v
        | Error (`Msg s) -> failwith @@ s
    else (Printf.printf "got none\n"; None)
end
