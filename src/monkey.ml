open Util
open ExpUtil
open Printf
open Config

(**************** Initialization ***************)
(*
 * DB for this experiment is made here.
 *)
let db = 
  let conn = Scylla.connect ~ip:ip ~port:!_port |> Result.get_ok in
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

let master_init () = 
  begin
    fail_if_error @@ DB.fresh_init db;
    printf "DB initialized. Tables created.\n";
    let (data: Doc.t) = read_doc_file () in
    printf "Doc file read\n";
    System.set_root db (DB.new_root db !_branch data);
    printf "Master branch created.\n";
    flush stdout;
  end

let rec child_init ?(n_tries=5) () = 
  match (n_tries, DB.fork db "master" !_branch) with
  | (_, Some _) -> printf "Child branch %s created.\n%!" !_branch
  | (n, None) when n>1 -> (Unix.sleepf 0.2; 
              child_init ~n_tries:(n_tries-1) ())
  | _ -> failwith "Master could not be found!"

let rec wait_for_all () =
  let brs = List.sort_uniq String.compare @@ 
        HeadMap.list_branches db in
  if List.length brs < !_n_branches 
  then
    (Unix.sleepf 0.2; wait_for_all ())
  else
    let my_i = index_of !_branch brs in
    let (prev_i, next_i) = 
      ((my_i + !_n_branches -1) mod !_n_branches, 
       (my_i + 1) mod !_n_branches) in
    begin
      ignore @@ List.find (fun b' -> b' = !_branch) brs;
      _branch_list := brs;
      _prev_branch := List.nth brs prev_i;
      _next_branch := List.nth brs next_i;
      printf "%s --> %s --> %s\n%!" !_prev_branch 
        !_branch !_next_branch;
    end

let do_an_edit doc = 
  SString.mutate_random doc

let loop_iter fp i (pre: Doc.t Lwt.t) : Doc.t Lwt.t = 
  let$ doc = pre in 
  (*let t1 = Unix.time() in*)
  let doc' = do_an_edit doc in
  let mdoc_lwt = 
    let t1 = Unix.gettimeofday () in
    let$ doc = DB.local_sync db !_branch doc' in
    let t2 = Unix.gettimeofday () in 
    let _ = comp_time := !comp_time +. (t2 -. t1) in
    let$ () = Lwt_io.fprintf fp "%fs\n" @@ t2 -. t1 >>= 
            fun _ -> Lwt_io.flush fp in
    Lwt.return doc in
  let sleep_lwt = Lwt_unix.sleep 0.5 in
  let$ (mdoc,()) = Lwt.both mdoc_lwt sleep_lwt in
  let$ () = Lwt_io.printf "[%s] Round %d\n" !_branch i 
                >>= fun _ -> Lwt_io.(flush stdout) in
  Lwt.return mdoc


let work_loop fp : unit Lwt.t = 
  let$ _ = ExpUtil.fold (loop_iter fp) !_n_rounds @@ 
             Lwt.return @@ Option.get @@ DB.read db !_branch in
  Lwt.return ()

let rec sync_loop () : unit Lwt.t = 
  let$ sync_res = DB.sync db !_branch in
  let$ () = print_sync_res sync_res >>= fun _ -> 
                Lwt_io.(flush stdout) in
  (*let r = (float @@ (Random.int 5) + 1) *. 0.01 in
  let$ () = Lwt_unix.sleep r in*)
  sync_loop ()


let experiment_lwt () = 
  let fname = sprintf "%s_latency_%d.csv" !_branch 
              (int_of_float @@ Unix.time()) in
  let _ = printf "Latency results will be written to %s\n" fname in
  let$ fp = Lwt_io.open_file ~flags:[O_RDWR; O_CREAT]
              ~mode:Lwt_io.Output fname in
  let$_ = Lwt.pick [work_loop fp; 
            (*Lwt_unix.sleep 1.0 >>= fun _ ->*) sync_loop ()] in
  Lwt_io.close fp

let experiment_f () : unit =
  (* Scylla conn established and DB created already. *)
  let () = if !_is_master then master_init () 
           else child_init () in
  let () = wait_for_all () in
  let () = Lwt_main.run (experiment_lwt ())in
  begin
    let ctime = !comp_time in
    let total_rounds = !_n_rounds in
    let latency = ctime/.(float total_rounds) in
    printf "[%s] Avg. Latency = %fs\n" !_branch latency
  end


let arg_parse () = 
  let usage = "monkey [-master] --port port --nrounds nrounds" in
  let anon_fun _ = failwith "Anonymous arguments unexpected" in
  let spec = [("-master", Arg.Set _is_master, "Is this process master?");
              ("--port", Arg.Set_int _port, "Port of Scylla");
              ("--nrounds", Arg.Set_int _n_rounds, "Number of rounds"); 
              ("--nbranches", Arg.Set_int _n_branches, "Number of branches"); 
              ("--branch", Arg.Set_string _branch, "Name of this branch")] in
  begin
    Arg.parse spec anon_fun usage;
    if !_is_master then _branch := "master";
    (*
     * This makes sure _branch \in _branch_list.
     *)
    _branch_list := [!_branch];
    printf "is_master = %B; branch = %s; port=%d; nrounds=%d\n%!" 
              !_is_master !_branch !_port !_n_rounds;
  end

let main () =
  begin
    arg_parse ();
    Random.self_init ();
    experiment_f ();
    (*DB.debug_dump db;*)
    VersionGraph.debug_dump db;
  end;;

main ();;
