(** An implementation of Content.STORABLE for strings. *)

type t = string
let hash s = Digest.string s
let to_big = Util.big_of_string
let from_big = Bigstringaf.to_string
