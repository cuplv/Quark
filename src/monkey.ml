open Util
open ExpUtil
open Printf

(**************** Initialization ***************)
let ip = "127.0.0.1"
let port = 9042
let my_branch = "master"
let doc_file = "hello.txt"
(*
 * DB for this experiment is made here.
 *)
let db = 
  let conn = Scylla.connect ~ip:ip ~port:port |> Result.get_ok in
  let () = printf "Opened connection.\n" in
  System.make_db "my_store" conn
  
module Doc = SString
module IDoc = IString
module DB = MergeDB.Make(IDoc)
(*************************************************)

let read_doc_file () = 
  let fp = try open_in doc_file
           with Sys_error _ -> failwith @@ "Input file "^doc_file
                                ^" does not exist!" in
  let doc = really_input_string fp 1700 in
  doc
  (*try
    while true do
      doc := (input_line fp) :: !doc
    done; List.rev !doc
  with End_of_file -> (close_in fp; List.rev !doc)*)

let master_init () = 
  begin
    fail_if_error @@ DB.fresh_init db;
    printf "DB initialized. Tables created.\n";
    let (data: Doc.t) = read_doc_file () in
    printf "Doc file read\n";
    DB.new_root db my_branch data;
    printf "Master branch created.\n";
    flush stdout;
  end

let do_an_edit doc = 
  SString.mutate_random doc

let comp_time = ref 0.0

let sync_time = ref 0.0

let _n_ops_per_round = ref 30

let _n_rounds = ref 1000

let loop_iter i (pre: Doc.t Lwt.t) : Doc.t Lwt.t = 
  let$ doc = pre in 
  let t1 = Sys.time() in
  let doc' = do_an_edit doc in
  let mdoc_lwt = DB.local_sync db my_branch doc' in
  let sleep_lwt = Lwt_unix.sleep 0.5 in
  let$ (mdoc,()) = Lwt.both mdoc_lwt sleep_lwt in
  let t2 = Sys.time() in
  let () = comp_time := !comp_time +. (t2 -. t1) in
  let$ () = if true then 
              let lat  = !comp_time /. (float @@ i+1) in
              Lwt_io.printf "Round %d latency: %fs\n" i lat 
                >>= fun _ -> Lwt_io.(flush stdout)
            else Lwt.return () in
  Lwt.return mdoc


let work_loop () : unit Lwt.t = 
  let$ _ = ExpUtil.fold (loop_iter) !_n_rounds @@ 
             Lwt.return @@ Option.get @@ DB.read db my_branch in
  Lwt.return ()

let rec sync_loop () : unit Lwt.t = 
  let$ sync_res = DB.sync db my_branch in
  let$ () = print_sync_res sync_res >>= fun _ -> 
                Lwt_io.(flush stdout) in
  sync_loop ()


let reset () =
  begin 
    comp_time := 0.0;
  end

let experiment_f (fp: out_channel) : unit =
  (* Scylla conn established and DB created already. *)
  let () = if my_branch = "master" then master_init () else () in
  let () = Lwt_main.run (*work_loop ()*)@@ Lwt.pick 
              [work_loop (); 
               Lwt_unix.sleep 1.0 >>= fun _ -> sync_loop ()] in
  begin
    let ctime = !comp_time in
    let total_rounds = !_n_rounds in
    let latency = ctime/.(float total_rounds) in
    fprintf fp "%d,%d,%fs\n" 
                !_n_rounds !_n_ops_per_round 
                latency;
    reset ()
  end

let main () =
  begin
    if Array.length Sys.argv < 2 then
      failwith "_n_rounds argument expected\n";
    Random.self_init ();
    (*Logs.set_reporter @@ Logs.format_reporter ();
    Logs.set_level @@ Some Logs.Error;*)
    _n_rounds := int_of_string @@ Sys.argv.(1);
    let fp = open_out_gen [Open_append; Open_creat] 
              0o777 "results.csv" in
    experiment_f fp;
    close_out fp;
  end;;

main ();;
