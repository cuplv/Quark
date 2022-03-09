open Util
open System

type branch = Types.branch
type version = Version.t

type pull_error = Unrelated | Blocked of branch

module Make (Data : Content.TYPE) = struct

  module CStore = ContentStore.Make(Data)

  let get_head t = HeadMap.get t
  let set_head t = HeadMap.set t
  (*let get_lca t = LcaMap.get t*)
  let set_lca t = LcaMap.set t
  let get_cs t = CStore.get t
  let put_cs t = CStore.put t

  let get_lca db b1 b2 = 
    let@* v1 = get_head db b1 in
    let@* v2 = get_head db b2 in
    let vc1 = Version.vector_clock v1 in
    let vc2 = Version.vector_clock v2 in
    let lca_vc = vc_compute_glb vc1 vc2 in
    let _ = Printf.printf "vc1 = %s\nvc2 = %s\nlca = %s\n%!" 
      (vc_to_string vc1) (vc_to_string vc2) (vc_to_string lca_vc) in
    VersionGraph.get_version_by_vc db lca_vc

  let init {store_name=s;connection=conn; _} =
    let* _ = KeySpace.create_tag_ks conn in
    let* _ = KeySpace.create_content_ks conn in
    let* _ = CStore.init s conn in
    let* _ = HeadMap.init s conn in
    let* _ = LcaMap.init s conn in
    let* _ = VersionGraph.init s conn in
    let* _ = GlobalLock.init s conn in
    Ok ()

  let fresh_init db =
    let* _ = KeySpace.delete_tag_ks db.connection in
    let* _ = KeySpace.delete_content_ks db.connection in
    init db

  (** Get LCAs for the given branch with other related branches. *)
  let all_lcas_of : System.db -> branch -> (branch * version) list
    = fun db b ->
    let other_bs = List.filter
                     (fun b' -> b <> b')
                     (HeadMap.list_branches db) in
    let _ = Printf.printf "others: %s\n%!" @@ String.concat "," other_bs in 
    List.fold_right (fun b' ls -> match get_lca db b b' with
                                  | Some lca -> (b',lca) :: ls
                                  | None -> ls)
      other_bs
      []

  (** Get LCA pairs for the two given branches with other related branches. *)
  let all_lcas_of2 : System.db -> branch -> branch -> (branch * version * version) list
    = fun db b1 b2 ->
    (* Get other branches *)
    let other_bs = List.filter
                     (fun b' -> b' <> b1 && b' <> b2)
                     (HeadMap.list_branches db)
    in
    (* Get tuples (other_branch, lca_with_from, lca_with_into) *)
    List.fold_right
      (fun b' ls -> match (get_lca db b1 b',get_lca db b2 b') with
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

  let commit : System.db -> branch -> Data.o -> version option
    = fun db b d ->
    let@+ old_version = HeadMap.get db b in
    let d_t = Data.of_adt d in
    let hash = put_cs db d_t in
    let new_version = Version.bump old_version hash in
    let _ = VersionGraph.add_version
              db new_version [old_version] in
    let () = HeadMap.set db new_version in
    new_version

  let fork : System.db -> branch -> branch -> branch option
    = fun db old_branch new_branch ->
    if List.mem new_branch @@ HeadMap.list_branches db
    then failwith @@ "Branch "^new_branch^" exists!";
    let@+ old_version = HeadMap.get db old_branch in
    let new_version = Version.fork new_branch old_version in
    let _ = VersionGraph.add_version
              db new_version [old_version] in
    (* Setting the read/write consistency to quorum *)
    let _ = System.set_consistency Scylla.Protocol.Quorom db in
    let _ = set_lca db old_branch new_branch old_version in
    (* Resetting read/write consistency to default *)
    let _ = System.reset_consistency db in
    let _ = Printf.printf "LCAs with: " in
    let _ = List.iter (fun (b,_) -> Printf.printf "%s, " b) (all_lcas_of db old_branch) in
    let _ = Printf.printf "--- \n%!" in
    let _ = List.iter
              (fun (b',lca) -> set_lca db b' new_branch lca)
              (all_lcas_of db old_branch)
    in
    (* Setting the read/write consistency to quorum *)
    let _ = System.set_consistency Scylla.Protocol.Quorom db in
    let _ = HeadMap.set db new_version in
    (* Resetting read/write consistency to default *)
    let _ = System.reset_consistency db in
    new_branch

  (** Merge versions by applying the Data.merge function to their
     content. *)
  let merge : System.db -> version -> version -> version -> version
    = fun db lca_v from_v into_v ->
    let lca_d = get_cs db (Version.content_id lca_v) |> Option.get in
    let from_d = get_cs db (Version.content_id from_v) |> Option.get in
    let into_d = get_cs db (Version.content_id into_v) |> Option.get in
    let new_d = Data.merge lca_d from_d into_d in
    let new_c = put_cs db new_d in
    Version.merge from_v into_v new_c

  (*
   * The alternative to global locking is to obtain read locks on 2*(n-2)
   * rows in LcaMap table which requires 2*(n-2) CAS operations to check if
   * the current values is same as the value that was read at the beginning
   * of the pull. This would be more expensive than a global lock.
   *)
  let pull : System.db -> branch -> branch -> (unit, pull_error) result
    = fun db from_b into_b ->
    let into_v = HeadMap.get db into_b |> Option.get in
    let from_v = HeadMap.get db from_b |> Option.get in
    let lca_o = get_lca db from_b into_b in
    let res = match lca_o with
      | None -> Result.Error Unrelated
      | Some lca_v when lca_v = from_v -> 
        begin
          Printf.printf "Nothing to update\n%!";
          flush stdout;
          Result.Ok () (*Nothing to update*)
        end
      | Some lca_v -> 
        let new_v = if lca_v = into_v 
                    then Version.fastfwd from_v into_v
                    else merge db lca_v from_v into_v in
        (* Update head of into_b to the new version. *)
        let _ = HeadMap.set db new_v in
        (* Add new edges to version graph *)
        let _ = VersionGraph.add_version db new_v [from_v; into_v] in
        Result.Ok () in
    res


  let sync db this_b = 
    (*let$ _ = Lwt_io.printf "Sync called\n%!" in*)
    (* NOTE: not syncing from all the branches. *)
    (*let bs = HeadMap.list_branches db |> 
              List.filter (fun b -> b <> this_b) in*)
    let t1 = Unix.gettimeofday () in
    let bs = [!Config._prev_branch] in
    (* Obtain global lock *)
    let$ () = GlobalLock.acquire db this_b in
    let t1' = Unix.gettimeofday () in
    (* Setting the read/write consistency to quorum *)
    let _ = System.set_consistency Scylla.Protocol.Quorom db in
    let res = List.map (fun other_b -> pull db other_b this_b) bs in
    (* Resetting read/write consistency to default *)
    let _ = System.reset_consistency db in
    (* Release global lock *)
    let t2' = Unix.gettimeofday () in
    let _ = GlobalLock.release db this_b in
    let t2 = Unix.gettimeofday () in
    let _ = ignore (t1,t1',t2,t2') in
    (*let$ _ = Lwt_io.printf "Sync time = %fs. Total time= %fs\n%!"
        (t2'-.t1')  (t2 -. t1) in*)
    Lwt.return @@ List.combine bs res

  (*
   * This is hack. TODO: fix.
   *)
  let (prev_head_op: version option ref) = ref None

  let read : System.db -> branch -> Data.o option
    = fun db name ->
    let@+ v = get_head db name in
    let _ = prev_head_op := Some v in
    let d_t = get_cs db (Version.content_id v) |> Option.get in
    Data.to_adt d_t

  let local_sync db this_b new_d = 
    let prev_head = match !prev_head_op with 
        | Some v -> v
        | None -> failwith "prev_head is None" in
    let cur_head = get_head db this_b |> Option.get in
    if prev_head = cur_head then 
      let new_v = commit db this_b new_d |> Option.get in
      let _ = prev_head_op := Some new_v in
       Lwt.return new_d (* return same data *)
    else 
      let prev_d = Data.to_adt @@ Option.get @@ get_cs db @@ 
                      Version.content_id prev_head in
      let cur_d = Data.to_adt @@ Option.get @@ get_cs db @@ 
                      Version.content_id cur_head in
      let merged_d = Data.o_merge prev_d new_d cur_d in
      let new_v =  commit db this_b merged_d |> Option.get in
      let _ = prev_head_op := Some new_v in
      Lwt.return merged_d (* return merged data *)

  let new_root : System.db -> branch -> Data.o -> Version.t
    = fun db name d ->
    let d_t = Data.of_adt d in
    let hash = put_cs db d_t in
    let root = Version.init name hash in
    begin
      set_head db root;
      root
    end

  let debug_dump db =
    let () = VersionGraph.debug_dump db in
    let () = Printf.printf "\n" in
    let () = LcaMap.debug_dump db in
    let () = Printf.printf "\n" in
    let () = Printf.printf "Branches:\n" in
    let () = List.iter (fun b -> Printf.printf "%s, " b) (HeadMap.list_branches db) in
    Printf.printf "\n"
end
