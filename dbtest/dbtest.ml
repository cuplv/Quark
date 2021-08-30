module Set = Mrdt.Mset.Make (struct type t = int [@@deriving irmin] let compare = compare end)

let conn = Scylla.connect ~ip:"127.0.0.1" ~port:9042 |> Result.get_ok

let set1 = Set.init 0 "setA" [conn]

