let big_of_string s = Bigstringaf.of_string s ~off:0 ~len:(String.length s)

let get_value v =
  let v = (function Scylla.Protocol.Blob b -> b | _ -> failwith "error") v in
  v

(* merge lca v1 v2 -> v3 *)
type mergefun = string -> string -> string -> (string, string) result
