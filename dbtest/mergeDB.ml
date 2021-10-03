open Util

type branch = Types.branch
type version = Version.t

type pull_error = Unrelated | Blocked of branch

module type DATA = sig
  type t
  val merge3 : t -> t -> t -> t
  include Content.STORABLE with type data = t
end

module Make (Data : DATA) = struct
  module CStore = ContentStore.Make(Data)
  type handle =
    { head_map : HeadMap.handle;
      lca_map : LcaMap.handle;
      version_graph : VersionGraph.handle;
      content_store : CStore.handle
    }
  let get_head t = HeadMap.get t.head_map
  let set_head t = HeadMap.set t.head_map
  let get_lca t = LcaMap.get t.lca_map
  let set_lca t = LcaMap.set t.lca_map
  let get_cs t = CStore.get t.content_store
  let put_cs t = CStore.put t.content_store
  let init s conn =
    let* _ = KeySpace.create_tag_ks conn in
    let* _ = KeySpace.create_content_ks conn in
    let* cs = CStore.init s conn in
    let* h = HeadMap.init s conn in
    let* l = LcaMap.init s conn in
    let* graph = VersionGraph.init s conn in
    Ok
      { head_map = h;
        lca_map = l;
        version_graph = graph;
        content_store = cs
      }

  (** Get LCAs for the given branch with other related branches. *)
  let all_lcas_of : handle -> branch -> (branch * version) list
    = fun t b ->
    let other_bs = List.filter
                     (fun b' -> b <> b')
                     (HeadMap.list_branches t.head_map)
    in
    List.fold_right (fun b' ls -> match get_lca t b b' with
                                  | Some lca -> (b',lca) :: ls
                                  | None -> ls)
      other_bs
      []

  (** Get LCA pairs for the two given branches with other related branches. *)
  let all_lcas_of2 : handle -> branch -> branch -> (branch * version * version) list
    = fun t b1 b2 ->
    (* Get other branches *)
    let other_bs = List.filter
                     (fun b' -> b' <> b1 && b' <> b2)
                     (HeadMap.list_branches t.head_map)
    in
    (* Get tuples (other_branch, lca_with_from, lca_with_into) *)
    List.fold_right
      (fun b' ls -> match (get_lca t b1 b',get_lca t b2 b') with
                   | (Some lca1, Some lca2) -> (b', lca1, lca2) :: ls
                   | (None,None) -> ls
                   | (Some _,None) ->
                      let () = Printf.printf "Collect LCAs for (%s,%s) failed.\n" b1 b2 in
                      let () = Printf.printf "%s is related to %s and not %s.\n" b' b1 b2 in
                      exit 1
                   | (None,Some _) ->
                      let () = Printf.printf "Collect LCAs for (%s,%s) failed.\n" b1 b2 in
                      let () = Printf.printf "%s is related to %s and not %s.\n" b' b2 b1 in
                      exit 1)
      other_bs
      []
  let commit : handle -> branch -> Data.t -> unit option
    = fun t b d ->
    let@+ old_version = HeadMap.get t.head_map b in
    let hash = put_cs t d in
    let new_version = Version.bump old_version hash in
    let _ = VersionGraph.add_version
              t.version_graph
              new_version
              [old_version]
    in
    HeadMap.set t.head_map new_version
  let fork : handle -> branch -> branch -> branch option
    = fun t old_branch new_branch ->
    let@+ old_version = HeadMap.get t.head_map old_branch in
    let new_version = Version.fork new_branch old_version in
    let _ = VersionGraph.add_version
              t.version_graph
              new_version
              [old_version]
    in
    let _ = HeadMap.set t.head_map new_version in
    let _ = set_lca t old_branch new_branch old_version in
    let _ = List.iter
              (fun (b',lca) -> set_lca t b' new_branch lca)
              (all_lcas_of t old_branch)
    in
    new_branch

  (** Merge versions by applying the merge3 function to their
     content. *)
  let merge : handle -> version -> version -> version -> version
    = fun t lca_v from_v into_v ->
    let lca_d = get_cs t (Version.content_id lca_v) |> Option.get in
    let from_d = get_cs t (Version.content_id from_v) |> Option.get in
    let into_d = get_cs t (Version.content_id into_v) |> Option.get in
    let new_d = Data.merge3 lca_d from_d into_d in
    let new_c = put_cs t new_d in
    Version.bump into_v new_c

  let pull : handle -> branch -> branch -> (unit, pull_error) result
    = fun t from_b into_b ->
    let into_v = HeadMap.get t.head_map into_b |> Option.get in
    let from_v = HeadMap.get t.head_map from_b |> Option.get in
    let lca_o = get_lca t from_b into_b in
    match lca_o with
    | None -> Result.Error Unrelated
    | Some lca_v ->
       if lca_v = from_v
       then
         (* There is nothing to update. *)
         Ok ()
       else
         let other_lcas = all_lcas_of2 t from_b into_b in
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
            let new_v =
              if lca_v = into_v

              then Version.fastfwd from_v into_v

              else merge t lca_v from_v into_v
            in
            (* Update head of into_b to the new version. *)
            let _ = HeadMap.set t.head_map new_v in
            (* Update LCA between from_b and into_b, using from_b's head
               as LCA version. *)
            let _ = set_lca t from_b into_b from_v in
            (* Update the other branches' LCAs for into_b. *)
            let _ = List.map
                      (fun (other_b,from_lca,into_lca) ->
                        if VersionGraph.is_ancestor
                             t.version_graph
                             into_lca
                             from_lca
                        then set_lca t into_b other_b from_lca
                        else ())
                      other_lcas
            in
            (* Update was successful. *)
            Ok ()
         | Some (b,_,_) ->
            (* No database errors, but update was blocked due to this other branch. *)
            Error (Blocked b)
  let read : handle -> branch -> Data.t option
    = fun t name ->
    let@+ v = get_head t name in
    get_cs t (Version.content_id v) |> Option.get
  let new_root : handle -> branch -> Data.t -> unit
    = fun t name d ->
    let hash = put_cs t d in
    set_head t (Version.init name hash)
end
