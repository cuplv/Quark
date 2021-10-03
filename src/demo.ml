module DB = MergeDB.Make (StringData)

let earth = "Earth"

let moon = "Moon"

let conn = Scylla.connect ~ip:"127.0.0.1" ~port:9042 |> Result.get_ok

let () = Printf.printf "Opened connection.\n"

let db =
  match DB.fresh_init "my_store" conn with
  | Ok s -> s
  | Error e -> let () = Printf.printf "%s" e in exit 1

let () = Printf.printf "Created store tables.\n"

let latest b = Ok (DB.read db b |> Option.get)

let new_root b s =
  let _ = DB.new_root db b s in
  let () = Printf.printf "Created root branch %s with value \"%s\".\n"
             b
             (latest b |> Result.get_ok)
  in
  Ok ()

let commit b s =
  match DB.commit db b s with
  | Some () ->
     let () = Printf.printf "Updated branch %s to value \"%s\".\n"
                b
                (DB.read db b |> Option.get)
     in
     Some ()
  | None ->
     let () = Printf.printf
                "Update failed. Branch %s does not exist.\n"
                b
     in
     None

let fork b1 b2 =
  let r = DB.fork db b1 b2 |> Option.get in
  let () = Printf.printf "Forked new branch %s off of %s.\n" b2 b1 in
  r

let pull from_b into_b =
  match DB.pull db from_b into_b with
  | Ok () -> Printf.printf "Pulled from %s into %s to get \"%s\".\n"
               from_b
               into_b
               (latest into_b |> Result.get_ok)
  | Error Unrelated -> Printf.printf
                         "Pull failed: %s and %s are unrelated.\n"
                         from_b
                         into_b
  | Error (Blocked b) -> Printf.printf
                           "Pull failed: %s and %s are blocked by %s.\n"
                           from_b
                           into_b
                           b

let b1 = "b1"
let b2 = "b2"

let _ = new_root b1 "Hello"

let _ = fork b1 b2

let _ = commit b2 "Hello Earth"

let _ = commit b1 "Hello Moon"

let _ = pull b1 b2

let _ = commit b1 "Hello Moon, Mars"

let _ = pull b2 b1

let _ = pull b1 b2

let _ = commit b1 "Hello Moon Earth, Mars, etc."

let _ = pull b1 b2

let _ = new_root "c" "A"

let _ = fork "c" "ca1"
let _ = commit "ca1" "A1"

let _ = fork "c" "ca2"
let _ = commit "ca2" "A2"

let _ = fork "c" "cc1"
let _ = pull "ca1" "cc1"

let _ = fork "c" "cc2"
let _ = pull "ca2" "cc2"

let _ = fork "c" "cc3"
let _ = pull "ca1" "cc3"
let _ = pull "ca2" "cc3"

let _ = pull "cc2" "cc1"

let _ = Printf.printf "\n"

let () = DB.debug_dump db
