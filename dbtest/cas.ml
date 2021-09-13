(* open Scylla
 * open Scylla.Protocol *)

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

module type DATA = sig
  type t
  val hash : t -> Digest.t
end

module String : DATA = struct
  type t = String
  let hash = Digest.string
end

module Store (Data : DATA) = struct
end

let test = "Hi"
