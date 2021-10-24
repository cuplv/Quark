open Util
open System

let query = Scylla.query

module VSet = Set.Make(Version)

let create_graph_query s = Printf.sprintf
  "create table if not exists tag.%s_version_graph(
     child_branch blob,
     child_version_num int,
     child_content_id blob,
     parent_branch blob,
     parent_version_num int,
     parent_content_id blob,
     primary key (
       child_branch,
       child_version_num,
       parent_branch,
       parent_version_num))"
  s

let parents_query s = Printf.sprintf
  "select parent_branch, parent_version_num, parent_content_id
   from tag.%s_version_graph
   where child_branch = ? and child_version_num = ?"
  s

let add_query s = Printf.sprintf
  "insert into tag.%s_version_graph(
     child_branch,
     child_version_num,
     child_content_id,
     parent_branch,
     parent_version_num,
     parent_content_id)
   VALUES (?,?,?,?,?,?)"
  s

let debug_query s = Printf.sprintf
  "select 
     child_branch,
     child_version_num,
     child_content_id,
     parent_branch,
     parent_version_num,
     parent_content_id
   from tag.%s_version_graph"
  s


let init : string -> Scylla.conn -> (unit, string) result =
  fun s conn ->
  let* _ = query conn ~query:(create_graph_query s) () in
  Ok ()

let parents : System.db -> Version.t -> Version.t list =
  fun db v ->
  let r = query
            db.connection
            ~query:(parents_query db.store_name)
            ~values:(Array.sub (Version.to_row v) 0 2)
            ~consistency: db.consistency
            ()
          |> Result.get_ok
  in
  let f row ls = Version.of_row row :: ls in
  Array.fold_right f r.values []

let rec add_version : System.db -> Version.t -> Version.t list -> unit =
  fun db child parents ->
  match parents with
  | [] -> ()
  | p::ps ->
     let _ = query
               db.connection
               ~query:(add_query db.store_name)
               ~values:(Array.append
                          (Version.to_row child)
                          (Version.to_row p))
               ~consistency: db.consistency
               ()
             |> Result.get_ok
     in
     add_version db child ps

let rec hunt_for : System.db -> Version.t list -> Version.t -> bool =
  fun db vs v ->
  (* let _ = Printf.printf "Hunt for\n" in
   * let _ = List.iter (fun v -> Printf.printf "%s:%d " v.branch v.version_num) vs in
   * let _ = Printf.printf "\n" in *)
  match vs with
  | [] -> false
  | _ -> if List.exists (Version.succeeds_or_eq v) vs
         then true
         else let vs' = List.concat_map
                          (fun c -> parents db c)
                          vs
              in
              (* Remove duplicates. *)
              let vs'' = VSet.elements (VSet.of_list vs') in
              (* Continue search breadth-first. *)
              hunt_for db vs'' v

let is_ancestor db v1 v2 =
  hunt_for db (parents db v2) v1

let is_concurrent db v1 v2 =
  not (v1 = v2 || is_ancestor db v1 v2 || is_ancestor db v2 v1)

let debug_dump db =
  let r = query
            db.connection
            ~query:(debug_query db.store_name)
            ()
          |> Result.get_ok
  in
  let () = Printf.printf "Version graph: (child <- parent)\n" in
  Array.iter
    (fun row -> let c = Version.of_row (Array.sub row 0 3) in
                let p = Version.of_row (Array.sub row 3 3) in
                Printf.printf
                  "%s:%d <- %s:%d\n"
                  (Version.branch c)
                  (Version.version_num c)
                  (Version.branch p)
                  (Version.version_num p))
    r.values
