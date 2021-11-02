open Util
open ExpUtil

let conn = Scylla.connect ~ip:"127.0.0.1" ~port:9042 |> Result.get_ok

let () = Printf.printf "Opened connection.\n"

let db = System.make_db "my_store" conn

module Ilist = Ilist.Make(SInt)(struct let db=db end)
module DB = MergeDB.Make(Ilist)

let () =
  match DB.fresh_init db with
  | Ok s -> s
  | Error e -> let () = Printf.printf "%s" e in exit 1

let () = Printf.printf "Created store tables.\n"

let latest b = DB.read db b |> Option.get

let to_string v = List.map string_of_int v |> String.concat ";" 
                    |>  fun s -> "["^s^"]"

let new_root b data =
  let _ = DB.new_root db b data in
  let () = Printf.printf "Created root branch %s with value \"%s\".\n"
             b
             (latest b |> to_string)
  in
  ()

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

let alice_f : unit Lwt.t = 
  (* * Alice starts with a empty list.  *)
  let () = new_root "alice" [] in
  let () = flush_all () in
  let$ () = loop_until_y "1. Alice created Root. Can Alice commit?" in
  let () = commit "alice" [1;2] in
  let$ () = loop_until_y "4. Alice committed. Can Alice sync?" in
  let$ sync_res = DB.sync db "alice" in
  let$ () = print_sync_res sync_res in
  let$ () = loop_until_y "7. Alice synced. Can Alice commit?" in
  let v = latest "alice" in
  let v' = 11::v in
  let () = commit "alice" v' in
  let$ () = loop_until_y "10. Alice committed. Can Alice sync?" in
  let$ sync_res = DB.sync db "alice" in
  let$ () = print_sync_res sync_res in
  let v = latest "alice" in
  let$ () = Lwt_io.printf "Latest value on alice: %s\n" 
                @@ to_string v in
  (*Vpst.liftLwt @@ Lwt_unix.sleep 1.1 >>= fun () ->*)
  let$ () = loop_until_y "13. Alice done. End?" in
  Lwt.return ()

let () = 
  begin
    Lwt_main.run alice_f;
    DB.debug_dump db;
  end

