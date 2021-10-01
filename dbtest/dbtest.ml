module Store = Cas.Store (Cas.StrData)
module BS = BStore.Store
module VS = Version.Graph

open Util

let earth : Cas.StrData.t = "Earth"

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

let store = Store.store cs

let find = Store.find cs

(* A simple merge function for append-only strings. Assume that the
   LCA is a prefix of both strings (hence append-only), and then
   append the remainder of v1, and then the remainder of v2.

   For example, [str_merge "A" "AB" "AC" = "ABC"].

   If the new versions are not both longer than or equal to the LCA,
   then the second version is taken as the whole merged value.

  For example, [str_merge "AB" "ABC" "D" = "D"].

*)
let str_merge lca v1 v2 =
  let* lca_s = find lca in
  let* v1_s = find v1 in
  let* v2_s = find v2 in
  let _ = Printf.printf "Merging strings.\n" in
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
  Result.bind (BS.get_head bs b)  (fun k ->
  Result.bind (find (Version.content_id k)) (fun v ->
  Ok v ))

let update b s =
  let k = store s in
  let o = BS.get_head_opt bs b |> Result.get_ok in
  match o with
  | Some h -> 
      let r = BS.update_head bs (Version.bump h k) in
      let () = Printf.printf "Updated branch %s with value \"%s\".\n"
                 b
                 (latest b |> Result.get_ok)
      in
      r
  | None ->
     let r = BS.update_head bs (Version.init b k) in
     let () = Printf.printf "Created branch %s with value \"%s\".\n"
                b
                (latest b |> Result.get_ok)
     in
     r

let fork b1 b2 =
  let r = BS.fork bs b1 b2 in
  let () = Printf.printf "Forked new branch %s off of %s.\n" b2 b1 in
  r

let pull from_b into_b =
  let r = BS.pull str_merge bs from_b into_b in
  let () = Printf.printf "Pulled from %s into %s to get \"%s\".\n"
             from_b
             into_b
             (latest into_b |> Result.get_ok)
  in
  r

let b1 = "b1"
let b2 = "b2"

let _ = update b1 "Hello" |> Result.get_ok

let _ = fork b1 b2 |> Result.get_ok

let _ = update b2 "Hello Earth"

let _ = update b1 "Hello Moon"

let _ = pull b1 b2

let _ = update b1 "Hello Moon, Mars"

let _ = pull b2 b1

let _ = pull b1 b2

let _ = update b1 "Hello Moon Earth, Mars, etc."

let _ = pull b1 b2

let _ = update "c" "A"

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

let r = pull "cc2" "cc1"
let _ = match r with
  | Ok (Error b) -> Printf.printf "Merge blocked by %s.\n" b
  | Ok (Ok ()) -> Printf.printf "Merge not blocked.\n"
  | _ -> ()
