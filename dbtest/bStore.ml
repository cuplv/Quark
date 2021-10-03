open Scylla

open Util

type branch = Types.branch
type version = Version.t

let ks_query = Printf.sprintf
  "create keyspace if not exists bstore
   with replication = {
   'class':'SimpleStrategy',
   'replication_factor':1};"

module Store = struct
  type t =
    { store_name : string;
      connection : conn;
      head_map : HeadMap.handle;
      lca_map : LcaMap.handle;
      version_graph : VersionGraph.handle
    }
  type pull_error = Unrelated | Blocked of branch
  let init s conn =
    let* _ = query conn ~query:ks_query () in
    let* h = HeadMap.init s conn in
    let* l = LcaMap.init s conn in
    let* graph = VersionGraph.init s conn in
    Ok
      { store_name = s;
        connection = conn;
        head_map = h;
        lca_map = l;
        version_graph = graph
      }
  let get_other_lcas : t -> branch -> branch -> (branch * version * version) list
    = fun t b1 b2 ->
    (* Get other branches *)
    let other_bs = List.filter
                     (fun b -> b <> b1 && b <> b2)
                     (HeadMap.list_branches t.head_map)
    in
    (* Get tuples (other_branch, lca_with_from, lca_with_into) *)
    let l = t.lca_map in
    List.fold_right
      (fun b ls -> match (LcaMap.get l b1 b,LcaMap.get l b2 b) with
                   | (Some lca1, Some lca2) -> (b, lca1, lca2) :: ls
                   | (Some lca1, None) -> (b, lca1, lca1) :: ls
                   | _ -> ls)
      other_bs
      []
  let commit : t -> branch -> Content.id -> unit option
    = fun t b c ->
    let@+ old_version = HeadMap.get t.head_map b in
    let new_version = Version.bump old_version c in
    let _ = VersionGraph.add_version
              t.version_graph
              new_version
              [old_version]
    in
    HeadMap.set t.head_map new_version
  let fork : t -> branch -> branch -> (version, string) result
    = fun t old_branch new_branch ->
    let old_version = HeadMap.get t.head_map old_branch |> Option.get in
    let new_version = Version.fork new_branch old_version in
    let _ = VersionGraph.add_version
              t.version_graph
              new_version
              [old_version]
    in
    let _ = HeadMap.set t.head_map new_version in
    let _ = LcaMap.set t.lca_map old_branch new_branch old_version in
    let _ = List.iter
              (fun (b,lca,_) -> LcaMap.set t.lca_map b new_branch lca)
              (get_other_lcas t old_branch new_branch)
    in
    Ok new_version
  let pull : mergefun -> t -> branch -> branch -> ((unit, pull_error) result, string) result
    = fun mergefun t from_b into_b ->
    let into_v = HeadMap.get t.head_map into_b |> Option.get in
    let from_v = HeadMap.get t.head_map from_b |> Option.get in
    let lca_o = LcaMap.get t.lca_map from_b into_b in
    match lca_o with
    | None -> Ok (Result.Error Unrelated)
    | Some lca_v ->
       if lca_v = from_v
       then
         (* There is nothing to update. *)
         Ok (Ok ())
       else
         let other_lcas = get_other_lcas t from_b into_b in
         (* Find any violation of the "no concurrent LCAs for other
            branches" requirement. *)
         let r = List.find_opt
                   (fun (_,from_lca,into_lca) ->
                     VersionGraph.is_concurrent
                        t.version_graph
                        from_lca
                        into_lca)
                   other_lcas
         in
         match r with
         | None ->
            (* No violations of the requirement, proceeding with update. *)
   
            (* Create new version using either fastfwd or merge. *)
            let new_v = if lca_v = into_v
                        then Version.fastfwd from_v into_v
                        else Version.merge mergefun lca_v from_v into_v
                             |> Result.get_ok
            in
            (* Update head of into_b to the new version. *)
            let _ = HeadMap.set t.head_map new_v in
            (* Update LCA between from_b and into_b, using from_b's head
               as LCA version. *)
            let _ = LcaMap.set t.lca_map from_b into_b from_v in
            (* Update the other branches' LCAs for into_b. *)
            let _ = List.map
                      (fun (other_b,from_lca,into_lca) ->
                        if VersionGraph.is_ancestor
                             t.version_graph
                             into_lca
                             from_lca
                        then LcaMap.set t.lca_map into_b other_b from_lca
                        else ())
                      other_lcas
            in
            (* Update was successful. *)
            Ok (Ok ())
         | Some (b,_,_) ->
            (* No database errors, but update was blocked due to this other branch. *)
            Ok (Error (Blocked b))
  let read : t -> branch -> Content.id option
    = fun t name ->
    Option.map Version.content_id (HeadMap.get t.head_map name)
  let new_root : t -> branch -> Content.id -> unit
    = fun t name c ->
    HeadMap.set t.head_map (Version.init name c)
end
