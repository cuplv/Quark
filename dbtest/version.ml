open Scylla
open Scylla.Protocol

open Util

type conn = Scylla.conn

type value = Scylla.Protocol.value

type t =
  { branch : string;
    version_num : int;
    content_id : Cas.content_id;
  }

type version = t

let branch v = v.branch

let content_id v = v.content_id

let init : string -> Cas.content_id -> t =
  fun b c ->
  { branch = b;
    version_num = 0;
    content_id = c
  }

let succeeds_or_eq : t -> t -> bool =
  fun v2 v1 ->
  branch v1 = branch v2 && v1.version_num <= v2.version_num

let bump : t -> Cas.content_id -> t =
  fun v c ->
  { branch = v.branch;
    version_num = v.version_num + 1;
    content_id = c
  }

let fork new_branch v = init new_branch (content_id v)

let fastfwd from_v into_v = bump into_v (content_id from_v)

let merge f lca_v from_v into_v =
  let* new_cid = f lca_v.content_id
                   from_v.content_id
                   into_v.content_id
  in
  Ok (bump into_v new_cid)

let of_row : value array -> t =
  fun row ->
  { branch = get_string row.(0);
    version_num = get_int row.(1);
    content_id = get_string row.(2);
  }

let to_row : t -> value array =
  fun v ->
  [| Blob (big_of_string v.branch);
     Int (Int32.of_int v.version_num);
     Blob (big_of_string v.content_id)
  |]

let compare : t -> t -> int =
  fun v1 v2 ->
  let bc = String.compare v1.branch v2.branch in
  if bc = 0
  then let vc = Int.compare v1.version_num v2.version_num in
       if vc = 0
       then String.compare v1.content_id v2.content_id
       else vc
  else bc


module Graph = struct
  module VSet = Set.Make(struct
                    type t = version
                    let compare = compare
                  end)

  let create_graph_query s = Printf.sprintf
    "create table if not exists bstore.%s_version_graph(
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
     from bstore.%s_version_graph
     where child_branch = ? and child_version_num = ?"
    s
  
  let add_query s = Printf.sprintf
    "insert into bstore.%s_version_graph(
       child_branch,
       child_version_num,
       child_content_id,
       parent_branch,
       parent_version_num,
       parent_content_id)
     VALUES (?,?,?,?,?,?)"
    s

  type handle = table_handle
  let init : string -> conn -> (handle, string) result =
    fun s conn ->
    let* _ = query conn ~query:(create_graph_query s) () in
    Ok { store_name = s; connection = conn }
  let parents : handle -> t -> (t list, string) result =
    fun th v ->
    let* r = query
               th.connection
               ~query:(parents_query th.store_name)
               ~values:(Array.sub (to_row v) 0 2)
               ()
    in
    let f row ls = of_row row :: ls in
    Ok (Array.fold_right f r.values [])
  let rec add_version : handle -> t -> t list -> (unit, string) result =
    fun th child parents ->
    match parents with
    | [] -> Ok ()
    | p::ps ->
       let* _ = query
                  th.connection
                  ~query:(add_query th.store_name)
                  ~values:(Array.append (to_row child) (to_row p))
                  ()
       in
       add_version th child ps
  let rec hunt_for : handle -> t list -> t -> bool =
    fun th vs v ->
    (* let _ = Printf.printf "Hunt for\n" in
     * let _ = List.iter (fun v -> Printf.printf "%s:%d " v.branch v.version_num) vs in
     * let _ = Printf.printf "\n" in *)
    match vs with
    | [] -> false
    | _ -> if List.exists (succeeds_or_eq v) vs
           then true
           else let vs' = List.concat_map
                            (fun c -> parents th c |> Result.get_ok)
                            vs
                in
                (* Remove duplicates. *)
                let vs'' = VSet.elements (VSet.of_list vs') in
                (* Continue search breadth-first. *)
                hunt_for th vs'' v
  let is_ancestor th v1 v2 =
    hunt_for th (parents th v2 |> Result.get_ok) v1
  let is_concurrent th v1 v2 =
    not (is_ancestor th v1 v2 || is_ancestor th v2 v1)
end
