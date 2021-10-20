open Digestif
(*open Util*)
let big_of_string s = Bigstringaf.of_string s ~off:0 ~len:(String.length s)

module Irmin_SHA256 = Irmin.Hash.Make(SHA256)

type t = SHA256.t

let t = Irmin_SHA256.t

let digest_string s = SHA256.digest_string s

let digest_big_string s = SHA256.digest_bigstring s

let string t = SHA256.to_hex t

let big_string t = big_of_string @@ string t

let from_string t = SHA256.of_hex t

let equal t1 t2 = SHA256.equal t1 t2


