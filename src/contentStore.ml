open Scylla
open Scylla.Protocol (* Defines Scylla store value types *)

open Util
open System

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

  let to_json_string = Irmin.Type.to_json_string Stored.t
  let of_json_string = Irmin.Type.of_json_string Stored.t


  let init s conn =
    let* _ = query conn ~query:ks_query () in
    let* _ = query conn ~query:(create_query s) () in
    Ok () 
    
  let put db v =
    let json = big_of_string @@ to_json_string v in
    let hash = Hash.digest_big_string json in
    let kb = Blob (Hash.big_string hash) in
    (* let _ = Printf.printf "hash: %s\n" @@ Hash.string hash in
    let _ = Printf.printf "putting %s\n" @@ Scylla.show_value kb in *)
    let vb = Blob json in
    let _ = query
              db.connection
              ~query:(insert_query db.store_name)
              ~values:[|kb;vb|]
              ~consistency: db.consistency
              ()
            |> Result.get_ok in
    hash

  let get db hash =
    let kb = Blob (Hash.big_string hash) in
    (*let _ = Printf.printf "hash: %s\n" @@ Hash.string hash in
    let _ = Printf.printf "key:%s\n" @@ Scylla.show_value kb in*)
    let v = query
              db.connection
              ~query:(select_query db.store_name)
              ~values:[|kb|]
              ~consistency: db.consistency
              ()
            |> Result.get_ok
    in
    if Array.length v.values > 0
    then 
      let json_str = get_string v.values.(0).(0) in
      match of_json_string json_str with
        | Ok v -> Some v
        | Error (`Msg s) -> (Printf.printf "Json parsing failed!\n%!";
                            failwith @@ s)
    else (Printf.printf "got none\n"; None)
end
