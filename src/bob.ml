open Util
open ExpUtil

let conn = Scylla.connect ~ip:"127.0.0.1" ~port:9043 |> Result.get_ok

let () = Printf.printf "Opened connection.\n"

let db = System.make_db "my_store" conn

module Ilist = Ilist.Make(SInt)(struct let db=db end)
module DB = MergeDB.Make(Ilist)

let latest b = DB.read db b |> Option.get

let to_string v = List.map string_of_int v |> String.concat ";" 
                    |>  fun s -> "["^s^"]"

let commit b data =
  match DB.commit db b data with
  | Some () ->
     let v = DB.read db b |> Option.get |> to_string in
     let () = Printf.printf "Updated branch %s to value \"%s\".\n%!" b v in
      ()
  | None -> failwith @@
               Printf.sprintf
                "Update failed. Branch %s does not exist.\n" b

let fork b1 b2 =
  let r = DB.fork db b1 b2 |> Option.get in
  let () = Printf.printf "Forked new branch %s off of %s.\n%!" b2 b1 in
  r

(*
 * Starts here
 *)

let bob_f : unit Lwt.t = 
  (* * Bob forks from Alice  *)
  let bob = fork "alice" "bob" in
  let$ () = loop_until_y "2. Bob forked. Can Bob commit?" in
  let () = commit bob [3;4] in
  let$ () = loop_until_y "5. Bob committed. Can Bob sync?" in
  let$ sync_res = DB.sync db bob in
  let$ () = print_sync_res sync_res in
  let$ () = loop_until_y "8. Bob synced. Can Bob commit?" in
  let v = latest bob in
  let v' = 12::v in
  let () = commit bob v' in
  let$ () = loop_until_y "11. Bob committed. Can Bob sync?" in
  let$ sync_res = DB.sync db bob in
  let$ () = print_sync_res sync_res in
  let v = latest bob in
  let$ () = Lwt_io.printf "Latest value on bob: %s\n" 
                @@ to_string v in
  (*Vpst.liftLwt @@ Lwt_unix.sleep 1.1 >>= fun () ->*)
  Lwt.return ()

let () = 
  begin
    Lwt_main.run bob_f;
  end

