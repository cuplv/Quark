(*
 * Configuration for experiments
 *)
let ip = "127.0.0.1"
let _port = ref 9042
let _is_master = ref false
let _branch = 
  let hname = Unix.gethostname () in
  let pid = Unix.getpid () in
  ref @@ Printf.sprintf "%s.%d" hname pid
let _n_rounds = ref 1000
let doc_file = "hello.txt"
let _n_branches = ref 1
let _prev_branch = ref ""
let _next_branch = ref ""
let comp_time = ref 0.0
let sync_time = ref 0.0
let _n_ops_per_round = ref 30
let lock_interval = 0.01

