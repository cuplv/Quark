module Store = Cas.Store (Cas.StrData)
module BS = BStore.Store
module VS = Version.Graph

open Version

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
   append the remainder of v2, and then the remainder of v1.

   For example, str_merge("A","AC","AB") = "ABC" *)
let str_merge lca v1 v2 =
  Result.bind (find lca) (fun lca_s ->
  Result.bind (find v1)  (fun v1_s ->
  Result.bind (find v2)  (fun v2_s ->
  let _ = Printf.printf "Merging strings.\n" in
  let l = String.length lca_s in
  let d1 = String.sub v1_s l (String.length v1_s - l) in
  let d2 = String.sub v2_s l (String.length v2_s - l) in
  let hash = store (lca_s ^ d2 ^ d1) in
  Ok hash )))

let latest b =
  Result.bind (BS.get_head bs b)  (fun k ->
  Result.bind (find k.content_id) (fun v ->
  Ok v ))

let update b s =
  let k = store s in
  let o = BS.get_head_opt bs b |> Result.get_ok in
  match o with
  | Some h -> 
      let r = BS.update_head bs (bump_version h k) in
      let () = Printf.printf "Updated branch %s with value \"%s\".\n"
                 b
                 (latest b |> Result.get_ok)
      in
      r
  | None ->
     let r = BS.update_head bs (init_version b k) in
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
