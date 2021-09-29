open Scylla
open Scylla.Protocol

open Util

let ks_query = Printf.sprintf
  "create keyspace if not exists cas
   with replication = {
   'class':'SimpleStrategy',
   'replication_factor':1};"

let create_query s = Printf.sprintf
  "create table if not exists cas.%s(
   key blob,
   value blob,
   primary key (key))"
  s

let insert_query s = Printf.sprintf
  "insert into cas.%s(
   key,
   value)
   VALUES (?,?)"
  s

let select_query s = Printf.sprintf
  "select value from cas.%s where key = ?"
  s

type content_id = Digest.t

module type DATA = sig
  type t
  val hash : t -> Digest.t
  val to_big : t -> Bigstringaf.t
  val from_big : Bigstringaf.t -> t
end

module StrData : DATA with type t = string = struct
  type t = string
  let hash s = Digest.string s
  let to_big = big_of_string
  let from_big = Bigstringaf.to_string
end

module Store (Data : DATA) = struct
  type t = { store_name : string; connection : conn }
  let init s conn =
    let r1 = query conn ~query:ks_query () in
    let r2 = Result.bind
               r1
               (fun _ -> query conn ~query:(create_query s) ()) in
    Result.map (fun _ -> { store_name = s; connection = conn }) r2
    
  let store t v =
    let hash = Data.hash v in
    let kb = Blob (big_of_string hash) in
    let vb = Blob (Data.to_big v) in
    let _ = query
              t.connection
              ~query:(insert_query t.store_name)
              ~values:[|kb;vb|]
              ()
            |> Result.get_ok in
    hash
  let find t hash =
    let kb = Blob (big_of_string hash) in
    let r = query
              t.connection
              ~query:(select_query t.store_name)
              ~values:[|kb|]
              ()
    in
    Result.map (fun v -> Data.from_big (get_blob v.values.(0).(0))) r
end
