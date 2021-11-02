let big_of_string s = Bigstringaf.of_string s ~off:0 ~len:(String.length s)

let get_blob v =
  let v = (function Scylla.Protocol.Blob b -> b | _ -> failwith "error") v in
  v

let get_string v = Bigstringaf.to_string (get_blob v)

let get_int v =
  let v = (function Scylla.Protocol.Int b -> b | _ -> failwith "error") v in
  Int32.to_int v

(* merge lca v1 v2 -> v3 *)
type mergefun = string -> string -> string -> (string, string) result

let (let*) x f = Result.bind x f
let (let+) x f = Result.map f x
let (let@+) x f = Option.map f x
let (let$) = Lwt.bind
let (and$) = Lwt.both

let rec loop_until_y (msg:string) : unit Lwt.t = 
  let$ () = Lwt_io.printf "%s" msg in
  let$ str = Lwt_io.read_line Lwt_io.stdin in
  if str="y" then Lwt.return ()
  else loop_until_y msg

