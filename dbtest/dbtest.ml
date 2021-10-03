module Store = ContentStore.Make (StringData)
module BS = BStore.Store
module VS = VersionGraph

let earth = "Earth"

let moon = "Moon"

let () = Printf.printf "Opening connection...\n"

let conn = Scylla.connect ~ip:"127.0.0.1" ~port:9042 |> Result.get_ok

let () = Printf.printf "Opened connection.\n"

let cs =
  match Store.init "store2" conn with
  | Ok s -> s
  | Error e -> let () = Printf.printf "%s" e in exit 1

let bs =
  match BS.init "store2" conn with
  | Ok s -> s
  | Error e -> let () = Printf.printf "%s" e in exit 1

let vs =
  match VS.init "store2" conn with
  | Ok s -> s
  | Error e -> let () = Printf.printf "%s" e in exit 1

let () = Printf.printf "Created store tables.\n"

let store = Store.put cs

let find = Store.get cs

(* A simple merge function for append-only strings. Assume that the
   LCA is a prefix of both strings (hence append-only), and then
   append the remainder of v1, and then the remainder of v2.

   For example, [str_merge "A" "AB" "AC" = "ABC"].

   If the new versions are not both longer than or equal to the LCA,
   then the second version is taken as the whole merged value.

  For example, [str_merge "AB" "ABC" "D" = "D"].

*)
let str_merge lca v1 v2 =
  let lca_s = find lca |> Option.get in
  let v1_s = find v1 |> Option.get in
  let v2_s = find v2 |> Option.get in
  if String.length lca_s <= String.length v1_s
     && String.length lca_s <= String.length v2_s
  then
    let l = String.length lca_s in
    let d1 = String.sub v1_s l (String.length v1_s - l) in
    let d2 = String.sub v2_s l (String.length v2_s - l) in
    let hash = store (lca_s ^ d1 ^ d2) in
    Ok hash
  else
    Ok v2

let latest b =
  let c = BS.read bs b |> Option.get in
  Ok (find c |> Option.get)

let new_root b s =
  let c = store s in
  let _ = BS.new_root bs b c in
  let () = Printf.printf "Created root branch %s with value \"%s\".\n"
             b
             (latest b |> Result.get_ok)
  in
  Ok ()

let update b s =
  let k = store s in
  match BS.commit bs b k with
  | Some () ->
     let () = Printf.printf "Updated branch %s to value \"%s\".\n"
                b
                (BS.read bs b |> Option.get |> find |> Option.get)
     in
     Some ()
  | None ->
     let () = Printf.printf
                "Update failed. Branch %s does not exist.\n"
                b
     in
     None

let fork b1 b2 =
  let r = BS.fork bs b1 b2 in
  let () = Printf.printf "Forked new branch %s off of %s.\n" b2 b1 in
  r

let pull from_b into_b =
  match BS.pull str_merge bs from_b into_b |> Result.get_ok with
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

let _ = update b2 "Hello Earth"

let _ = update b1 "Hello Moon"

let _ = pull b1 b2

let _ = update b1 "Hello Moon, Mars"

let _ = pull b2 b1

let _ = pull b1 b2

let _ = update b1 "Hello Moon Earth, Mars, etc."

let _ = pull b1 b2

let _ = new_root "c" "A"

let _ = fork "c" "ca1"
let _ = update "ca1" "A1"

let _ = fork "c" "ca2"
let _ = update "ca2" "A2"

let _ = fork "c" "cc1"
let _ = pull "ca1" "cc1"

let _ = fork "c" "cc2"
let _ = pull "ca2" "cc2"

let _ = fork "c" "cc3"
let _ = pull "ca1" "cc3"
let _ = pull "ca2" "cc3"

let _ = pull "cc2" "cc1"
