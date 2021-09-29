open Scylla
open Scylla.Protocol

open Util


(* A version in a branch's history *)
type version =
  { branch : string;
    version_num : int;
    content_id : Cas.content_id;
  }

let init_version : string -> Cas.content_id -> version =
  fun b c ->
  { branch = b;
    version_num = 0;
    content_id = c
  }

let bump_version : version -> Cas.content_id -> version =
  fun v c ->
  { branch = v.branch;
    version_num = v.version_num + 1;
    content_id = c
  }

let version_from_row : value array -> version =
  fun row ->
  { branch = get_string row.(0);
    version_num = get_int row.(1);
    content_id = get_string row.(2);
  }

let version_to_row : version -> value array =
  fun v ->
  [| Blob (big_of_string v.branch);
     Int (Int32.of_int v.version_num);
     Blob (big_of_string v.content_id)
  |]

module type Graph_type = sig
  type t
  val init : string -> conn -> (t, string) result
  val parents : t -> version -> (version list, string) result
  val add_version : t -> version -> version list -> (unit, string) result
end

module Graph : Graph_type = struct
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
    "select parent_branch, parent_version, parent_content_id
     from bstore.%s_version_graph
     where child_branch = ? and child_version = ?"
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

  type t = table_handle
  let init : string -> conn -> (t, string) result =
    fun s conn ->
    let* _ = query conn ~query:(create_graph_query s) () in
    Ok { store_name = s; connection = conn }
  let parents : t -> version -> (version list, string) result =
    fun th v ->
    let* r = query
               th.connection
               ~query:(parents_query th.store_name)
               ~values:[|
                 Blob (big_of_string v.branch);
                 Int (Int32.of_int v.version_num)
               |]
               ()
    in
    let f : value array -> version list -> version list =
      fun row ls ->
      { branch = get_string row.(0);
        version_num = get_int row.(1);
        content_id = get_string row.(2);
      }
      :: ls
    in
    Ok (Array.fold_right f r.values [])
  let rec add_version : t -> version -> version list -> (unit, string) result =
    fun th child parents ->
    match parents with
    | [] -> Ok ()
    | p::ps ->
       let* _ = query
                  th.connection
                  ~query:(add_query th.store_name)
                  ~values:[|
                    (* Child values *)
                    Blob (big_of_string child.branch);
                    Int (Int32.of_int child.version_num);
                    Blob (big_of_string child.content_id);
                    (* Parent values *)
                    Blob (big_of_string p.branch);
                    Int (Int32.of_int p.version_num);
                    Blob (big_of_string p.content_id)
                  |]
                  ()
       in
       add_version th child ps
end
