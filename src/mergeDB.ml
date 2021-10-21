open Util
open System

type branch = Types.branch
type version = Version.t

type pull_error = Unrelated | Blocked of branch

module Make (Data : Content.TYPE) = struct

  module CStore = ContentStore.Make(Data)

  let get_head t = HeadMap.get t
  let set_head t = HeadMap.set t
  let get_lca t = LcaMap.get t
  let set_lca t = LcaMap.set t
  let get_cs t = CStore.get t
  let put_cs t = CStore.put t

  let init {store_name=s;connection=conn} =
    let* _ = KeySpace.create_tag_ks conn in
    let* _ = KeySpace.create_content_ks conn in
    let* _ = CStore.init s conn in
    let* _ = HeadMap.init s conn in
    let* _ = LcaMap.init s conn in
    let* _ = VersionGraph.init s conn in
    Ok ()

  let fresh_init db =
    let* _ = KeySpace.delete_tag_ks db.connection in
    init db

  (** Get LCAs for the given branch with other related branches. *)
  let all_lcas_of : System.db -> branch -> (branch * version) list
    = fun t b ->
    let other_bs = List.filter
                     (fun b' -> b <> b')
                     (HeadMap.list_branches t)
    in
    List.fold_right (fun b' ls -> match get_lca t b b' with
                                  | Some lca -> (b',lca) :: ls
                                  | None -> ls)
      other_bs
      []

  (** Get LCA pairs for the two given branches with other related branches. *)
  let all_lcas_of2 : System.db -> branch -> branch -> (branch * version * version) list
    = fun t b1 b2 ->
    (* Get other branches *)
    let other_bs = List.filter
                     (fun b' -> b' <> b1 && b' <> b2)
                     (HeadMap.list_branches t)
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

  let commit : System.db -> branch -> Data.o -> unit option
    = fun t b d ->
    let@+ old_version = HeadMap.get t b in
    let d_t = Data.of_adt d in
    let hash = put_cs t d_t in
    let new_version = Version.bump old_version hash in
    let _ = VersionGraph.add_version
              t new_version [old_version]
    in
    HeadMap.set t new_version

  let fork : System.db -> branch -> branch -> branch option
    = fun t old_branch new_branch ->
    let@+ old_version = HeadMap.get t old_branch in
    let new_version = Version.fork new_branch old_version in
    let _ = VersionGraph.add_version
              t new_version [old_version] in
    let _ = set_lca t old_branch new_branch old_version in
    let _ = Printf.printf "LCAs with: " in
    let _ = List.iter (fun (b,_) -> Printf.printf "%s, " b) (all_lcas_of t old_branch) in
    let _ = Printf.printf "\n" in
    let _ = List.iter
              (fun (b',lca) -> set_lca t b' new_branch lca)
              (all_lcas_of t old_branch)
    in
    let _ = HeadMap.set t new_version in
    new_branch

  (** Merge versions by applying the Data.merge function to their
     content. *)
  let merge : System.db -> version -> version -> version -> version
    = fun t lca_v from_v into_v ->
    let lca_d = get_cs t (Version.content_id lca_v) |> Option.get in
    let from_d = get_cs t (Version.content_id from_v) |> Option.get in
    let into_d = get_cs t (Version.content_id into_v) |> Option.get in
    let new_d = Data.merge lca_d from_d into_d in
    let new_c = put_cs t new_d in
    Version.bump into_v new_c

  let pull : System.db -> branch -> branch -> (unit, pull_error) result
    = fun t from_b into_b ->
    let into_v = HeadMap.get t into_b |> Option.get in
    let from_v = HeadMap.get t from_b |> Option.get in
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
                        t from_lca into_lca)
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
            let _ = HeadMap.set t new_v in
            (* Update LCA between from_b and into_b, using from_b's head
               as LCA version. *)
            let _ = set_lca t from_b into_b from_v in
            (* Update the other branches' LCAs for into_b. *)
            let _ = List.map
                      (fun (other_b,from_lca,into_lca) ->
                        if VersionGraph.is_ancestor
                             t into_lca from_lca
                        then set_lca t into_b other_b from_lca
                        else ())
                      other_lcas
            in
            (* Update was successful. *)
            Ok ()
         | Some (b,_,_) ->
            (* Update was blocked due to this other branch. *)
            Error (Blocked b)

  let read : System.db -> branch -> Data.o option
    = fun t name ->
    let@+ v = get_head t name in
    let d_t = get_cs t (Version.content_id v) |> Option.get in
    Data.to_adt d_t

  let new_root : System.db -> branch -> Data.o -> unit
    = fun t name d ->
    let d_t = Data.of_adt d in
    let hash = put_cs t d_t in
    set_head t (Version.init name hash)

  let debug_dump t =
    let () = VersionGraph.debug_dump t in
    let () = Printf.printf "\n" in
    let () = LcaMap.debug_dump t in
    let () = Printf.printf "\n" in
    let () = Printf.printf "Branches:\n" in
    let () = List.iter (fun b -> Printf.printf "%s, " b) (HeadMap.list_branches t) in
    Printf.printf "\n"
end
