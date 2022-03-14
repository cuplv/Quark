open Scylla
open Scylla.Protocol (* Defines Scylla store value types *)

open Util
open System

let ks_query = Printf.sprintf
  "create keyspace if not exists content
   with replication = {
   'class':'SimpleStrategy',
   'replication_factor':3};"

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


  let (cache : (Hash.t, Stored.t) Hashtbl.t) = Hashtbl.create 11177

  let to_json_string = Irmin.Type.to_json_string Stored.t
  let of_json_string = Irmin.Type.of_json_string Stored.t


  let init s conn =
    (*let* _ = query conn ~query:ks_query () in*)
    let* _ = query conn ~query:(create_query s) () in
    Ok () 
    
  let put db v =
    let json_str = to_json_string v in
    (*let _ = match of_json_string json_str with
            | Ok _ -> ()
            | Error (`Msg s) ->(Printf.printf "Invalid json generated!\n%!";
                                Printf.printf "%s\n%!" json_str;
                                failwith @@ s) in&*)
    let json = big_of_string json_str in
    let hash = Hash.digest_big_string json in
    begin
      if not @@ Hashtbl.mem cache hash then
      begin
        query
          db.connection
          ~query:(insert_query db.store_name)
          ~values:[| Blob (Hash.big_string hash);
                     Blob json |]
          ~consistency: db.consistency
          ()
        |> Result.get_ok |> ignore;
        Hashtbl.add cache hash v
      end;
      hash
    end

  let get (db:System.db) (hash:Hash.t) : Stored.t option =
    match Hashtbl.find_opt cache hash with
    | Some v -> Some v
    | None -> 
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
          | Ok v -> (Hashtbl.add cache hash v; Some v)
          | Error (`Msg s) -> (Printf.printf "Json parsing failed!\n%!";
                              Printf.printf "%s\n%!" json_str;
                              failwith @@ s)
      else None
end
