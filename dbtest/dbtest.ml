module Store = Cas.Store (Cas.StrData)

let earth : Cas.StrData.t = "Earth"

let moon = "Moon"

let conn = Scylla.connect ~ip:"127.0.0.1" ~port:9042 |> Result.get_ok

let () = Printf.printf "Opened connection.\n"

let s =
  match Store.init "store1" conn with
  | Ok s -> s
  | Error e -> let () = Printf.printf "%s" e in exit 1

let store = Store.store s

let find = Store.find s

let () = Printf.printf "Created store.\n"

let k1 = store earth

let k2 = store moon

let () = Printf.printf "Stored items.\n"

let () = Printf.printf "Found \"%s\".\n" (find k1 |> Result.get_ok)

let () = Printf.printf "Found \"%s\".\n" (find k2 |> Result.get_ok)
