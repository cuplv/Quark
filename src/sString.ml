(** Content.COMPARABLE strings. We also implement a random mutation. *)

type t = string

let compare = String.compare

let mutate_random s = 
  let b = Bytes.of_string s in
  let i = Random.int @@ String.length s in 
  let c = Char.chr @@ Random.int 256 in
  let () = Bytes.set b i c in
  Bytes.to_string b

let t = Irmin.Type.string

