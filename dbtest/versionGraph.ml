open Util

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

type handle = table_handle

let init : string -> Scylla.conn -> (handle, string) result =
  fun s conn ->
  let* _ = query conn ~query:(create_graph_query s) () in
  Ok { store_name = s; connection = conn }
let parents : handle -> Version.t -> Version.t list =
  fun th v ->
  let r = query
            th.connection
            ~query:(parents_query th.store_name)
            ~values:(Array.sub (Version.to_row v) 0 2)
            ()
          |> Result.get_ok
  in
  let f row ls = Version.of_row row :: ls in
  Array.fold_right f r.values []
let rec add_version : handle -> Version.t -> Version.t list -> unit =
  fun th child parents ->
  match parents with
  | [] -> ()
  | p::ps ->
     let _ = query
               th.connection
               ~query:(add_query th.store_name)
               ~values:(Array.append
                          (Version.to_row child)
                          (Version.to_row p))
               ()
             |> Result.get_ok
     in
     add_version th child ps
let rec hunt_for : handle -> Version.t list -> Version.t -> bool =
  fun th vs v ->
  (* let _ = Printf.printf "Hunt for\n" in
   * let _ = List.iter (fun v -> Printf.printf "%s:%d " v.branch v.version_num) vs in
   * let _ = Printf.printf "\n" in *)
  match vs with
  | [] -> false
  | _ -> if List.exists (Version.succeeds_or_eq v) vs
         then true
         else let vs' = List.concat_map
                          (fun c -> parents th c)
                          vs
              in
              (* Remove duplicates. *)
              let vs'' = VSet.elements (VSet.of_list vs') in
              (* Continue search breadth-first. *)
              hunt_for th vs'' v
let is_ancestor th v1 v2 =
  hunt_for th (parents th v2) v1
let is_concurrent th v1 v2 =
  not (is_ancestor th v1 v2 || is_ancestor th v2 v1)
