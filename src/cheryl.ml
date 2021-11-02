open Util
open ExpUtil

let conn = Scylla.connect ~ip:"127.0.0.1" ~port:9044 |> Result.get_ok

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

let cheryl_f : unit Lwt.t = 
  (* * Cheryl forks from Alice  *)
  let cheryl = fork "alice" "cheryl" in
  let$ () = loop_until_y "3. Cheryl forked. Can Cheryl commit?" in
  let () = commit cheryl [5;6] in
  let$ () = loop_until_y "6. Cheryl committed. Can Cheryl sync?" in
  let$ sync_res = DB.sync db cheryl in
  let$ () = print_sync_res sync_res in
  let$ () = loop_until_y "9. Cheryl synced. Can Cheryl commit?" in
  let v = latest cheryl in
  let v' = 13::v in
  let () = commit cheryl v' in
  let$ () = loop_until_y "12. Cheryl committed. Can Cheryl sync?" in
  let$ sync_res = DB.sync db cheryl in
  let$ () = print_sync_res sync_res in
  let v = latest cheryl in
  let$ () = Lwt_io.printf "Latest value on cheryl: %s\n" 
                @@ to_string v in
  (*Vpst.liftLwt @@ Lwt_unix.sleep 1.1 >>= fun () ->*)
  Lwt.return ()

let () = 
  begin
    Lwt_main.run cheryl_f;
  end

