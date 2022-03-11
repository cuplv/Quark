open Util
open System

let query = Scylla.query

module VSet = Set.Make(Version)

let create_graph_query s = Printf.sprintf
  "create table if not exists tag.%s_version_graph(
     child_branch blob,
     child_version_num int,
     child_content_id blob,
     child_vector_clock blob,
     child_timestamp blob,
     parent_branch blob,
     parent_version_num int,
     parent_content_id blob,
     parent_vector_clock blob,
     parent_timestamp blob,
     primary key (
       child_branch,
       child_version_num,
       parent_branch,
       parent_version_num))"
  s

let create_map_query s = Printf.sprintf
  "create table if not exists tag.%s_version_map(
     branch blob,
     version_num int,
     content_id blob,
     vector_clock blob,
     timestamp blob,
     primary key (vector_clock))"
  s

let get_version_by_vc_query s = Printf.sprintf
  "select branch, version_num, content_id,
    vector_clock, timestamp
    from tag.%s_version_map
    where vector_clock = ?"
  s

let parents_query s = Printf.sprintf
  "select parent_branch, parent_version_num, parent_content_id,
    parent_vector_clock, parent_timestamp
   from tag.%s_version_graph
   where child_branch = ? and child_version_num = ?"
  s

let add_vertex_query s = Printf.sprintf
  "insert into tag.%s_version_map(
     branch,
     version_num,
     content_id,
     vector_clock,
     timestamp)
   VALUES (?,?,?,?,?)"
  s

let add_edge_query s = Printf.sprintf
  "insert into tag.%s_version_graph(
     child_branch,
     child_version_num,
     child_content_id,
     child_vector_clock,
     child_timestamp,
     parent_branch,
     parent_version_num,
     parent_content_id,
     parent_vector_clock,
     parent_timestamp)
   VALUES (?,?,?,?,?,?,?,?,?,?)"
  s

let debug_query s = Printf.sprintf
  "select 
     child_branch,
     child_version_num,
     child_content_id,
     child_vector_clock,
     child_timestamp,
     parent_branch,
     parent_version_num,
     parent_content_id,
     parent_vector_clock,
     parent_timestamp
   from tag.%s_version_graph"
  s


let init : string -> Scylla.conn -> (unit, string) result =
  fun s conn ->
  let* _ = query conn ~query:(create_graph_query s) () in
  let* _ = query conn ~query:(create_map_query s) () in
  Ok ()

let get_version_by_vc (db:System.db) (vc:vector_clock) 
    : Version.t option = 
  match vc with
  | [] -> failwith "Empty vector clock!"
  (*| [("master",1)] -> db.System.root
  | [(_,_)] -> failwith "Unexpected in get_version_by_vc"*)
  | _ -> 
    begin
      let vc_str = vc_to_string @@ vc_normal_form vc in
      let r = query
                db.connection
                ~query:(get_version_by_vc_query db.store_name)
                ~values:[| Blob (big_of_string vc_str) |]
                ~consistency: db.consistency
                ()
              |> Result.get_ok in
      match Array.length r.values with
      | 0 -> (Printf.printf "No version %s\n" vc_str; None)
      | _ -> Some (Version.of_row r.values.(0))
    end

let add_version : System.db -> Version.t -> Version.t list -> unit =
  fun db child parents ->
    let print_vcs vcs = List.iter 
        (fun p -> Printf.printf "%s\n" @@ vc_to_string @@
            Version.vector_clock p) vcs in
    let all_vcs = List.map Version.vector_clock (child::parents) in
    let lub_vc = vc_compute_lub all_vcs in
    let _ = if (Version.vector_clock child = lub_vc) then ()
            else (print_vcs (child::parents); 
                  Printf.printf "LUB: (%s)\n" @@ 
                      vc_to_string lub_vc;
                  assert false) in
    begin
      query
        db.connection
        ~query:(add_vertex_query db.store_name)
        ~values:(Version.to_row child)
        ~consistency: db.consistency
        () |> Result.get_ok |> ignore;
      List.iter 
        (fun p ->
          query
            db.connection
            ~query:(add_edge_query db.store_name)
            ~values:(Array.append
                       (Version.to_row child)
                       (Version.to_row p))
            ~consistency: db.consistency
            () |> Result.get_ok |> ignore) 
        parents;
    end

let is_ancestor _ v1 v2 =
  vc_is_leq (Version.vector_clock v1) (Version.vector_clock v2)

let is_concurrent db v1 v2 =
  not (v1 = v2 || is_ancestor db v1 v2 || is_ancestor db v2 v1)

let debug_dump db =
  let r = query
            db.connection
            ~query:(debug_query db.store_name)
            ()
          |> Result.get_ok
  in
  let () = Printf.printf "Version graph: (child <- parent)\n%!" in
  Array.iter
    (fun row -> let c = Version.of_row (Array.sub row 0 5) in
                let p = Version.of_row (Array.sub row 5 5) in
                Printf.printf
                  "%s:%d:(%s)<- %s:%d:(%s)\n"
                  (Version.branch c)
                  (Version.version_num c)
                  (vc_to_string @@ Version.vector_clock c)
                  (Version.branch p)
                  (Version.version_num p)
                  (vc_to_string @@ Version.vector_clock p))
    r.values
