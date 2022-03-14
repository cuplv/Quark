open Util
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
  
module Map = Mrbmap.Make(SInt)(SInt)
module IMap = Irbmap.Make(SInt)(SInt)(struct let db = db end)
module DB = MergeDB.Make(IMap)
(*************************************************)

let random_int () = Random.int ((1 lsl 30)-1)

let do_an_insert t = 
  let (k,v) = (random_int (), random_int ()) in
  Map.insert k v t

let do_a_delete t = 
  if Map.is_empty t then t
  else Map.remove (Map.choose t) t

let do_an_update t = 
  if Map.is_empty t then t
  else Map.modify (Map.choose t) (fun _ -> random_int ()) t

let do_an_oper t = 
  let dice = (Random.int 99) + 1 in
  if  dice <= 50 then
    do_an_insert t
  else if dice <= 75 then
    do_an_update t
  else
    do_a_delete t

let mk_init_map () = 
  ExpUtil.fold (fun _ t -> do_an_insert t) 500 Map.empty

(******)

let master_init () = 
  begin
    ExpUtil.fail_if_error @@ DB.fresh_init db;
    printf "DB initialized. Tables created.\n";
    let (m: Map.t) = mk_init_map () in
    printf "Initial RBMap built\n";
    ignore @@ DB.new_root db !_branch m;
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
    let my_i = ExpUtil.index_of !_branch brs in
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

let loop_iter fp i (pre: Map.t Lwt.t) : Map.t Lwt.t = 
  let$ m = pre in 
  (*let t1 = Unix.time() in*)
  let m' = do_an_oper m in
  let commit_lwt = 
    let t1 = Unix.gettimeofday () in
    let$ m'' = DB.local_sync db !_branch m' in
    let t2 = Unix.gettimeofday () in 
    let _ = comp_time := !comp_time +. (t2 -. t1) in
    let$ () = Lwt_io.fprintf fp "%fs\n" @@ t2 -. t1 
          (*>>= fun _ -> Lwt_io.flush fp*) in
    Lwt.return m'' in
  let sleep_lwt = Lwt_unix.sleep 0.1 in
  let$ (m'',()) = Lwt.both commit_lwt sleep_lwt in
  let$ () = Lwt_io.printf "[%s] Round %d\n" !_branch i 
                (*>>= fun _ -> Lwt_io.(flush stdout)*) in
  Lwt.return m''


let work_loop fp : unit Lwt.t = 
  let$ _ = ExpUtil.fold (loop_iter fp) !_n_rounds @@ 
             Lwt.return @@ Option.get @@ DB.read db !_branch in
  Lwt.return ()

let rec sync_loop () : unit Lwt.t = 
  let$ _ = DB.sync db !_branch in
  (*let$ () = print_sync_res sync_res >>= fun _ -> 
                Lwt_io.(flush stdout) in
  let r = (float @@ (Random.int 5) + 1) *. 0.01 in
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
  let usage = "rbmonkey [-master | --branch name] --port port --nrounds nrounds" in
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
  end;;

main ();;
