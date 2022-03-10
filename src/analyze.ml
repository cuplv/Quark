open Config
open Printf
open System
open Util
open Scylla
open Scylla.Protocol

let get_version_query s = Printf.sprintf
  "select child_branch, child_version_num, child_content_id,
    child_vector_clock, child_timestamp
   from tag.%s_version_graph
   where child_branch = ? and child_version_num = ?"
  s

let get_version db b n = 
  let r = query
            db.connection
            ~query:(get_version_query db.store_name)
            ~values:[| Blob (big_of_string b); 
                       Int (Int32.of_int n) |]
            ~consistency: One
            ()
          |> Result.get_ok in
  match Array.length r.values with
  | 0 -> None
  | _ -> Some (Version.of_row r.values.(0))

let log_staleness_for db fp pv = 
  let@+ v = get_version db (Version.branch pv)
                ((Version.version_num pv) + 1) in
  let diffs = List.remove_assoc (Version.branch pv) @@
                vc_diff (Version.vector_clock v)
                  (Version.vector_clock pv) in
  let ts = Version.timestamp v in
  let do_it b' n' = 
    let v' = get_version db b' n' |> Option.get in
    let ts' = Version.timestamp v' in
    fprintf fp "%fs\n%!" (ts -. ts') in
  begin
    List.iter 
      (fun (b',ns') -> List.iter (do_it b') ns')
      diffs;
      v
  end

let analyze_f db fp = 
  let rec do_it v = match log_staleness_for db fp v with
    | None -> ()
    | Some v' -> do_it v' in
  let root = get_version db !_branch 2 |> Option.get in
  do_it root

let arg_parse () = 
  let usage = "analyze --branch branch --port port --nbranches nbranches" in
  let anon_fun _ = failwith "Anonymous arguments unexpected" in
  let spec = [
              ("--port", Arg.Set_int _port, "Port of Scylla");
              ("--nbranches", Arg.Set_int _n_branches, "Number of branches"); 
              ("--branch", Arg.Set_string _branch, "Name of this branch")
            ] in
  begin
    Arg.parse spec anon_fun usage;
  end

let main () =
  begin
    arg_parse ();
    printf "---------- Staleness Analysis (%s) ---------------\n" !_branch;
    let conn = Scylla.connect ~ip:ip ~port:!_port |> Result.get_ok in
    let () = printf "Opened connection.\n" in
    let db = System.make_db "my_store" conn in
    _branch_list := HeadMap.list_branches db;
    assert (List.length !_branch_list = !_n_branches);
    let csv_name = sprintf "%s_staleness_%d.csv" !_branch 
                    (int_of_float @@ Unix.time ()) in
    let fp = open_out_gen [Open_append; Open_creat] 
              0o777 csv_name in
    analyze_f db fp;
    flush fp;
    close_out fp;
    printf "Done. Results printed in %s\n" csv_name;
  end;;

main ();;
