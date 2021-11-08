open Util
open Config

type value = Scylla.Protocol.value

type t =
  { branch : string;
    version_num : int;
    content_id : Hash.t;
    vector_clock: vector_clock;
    timestamp: float;
  }

let branch v = v.branch

let content_id v = v.content_id

let version_num v = v.version_num

let vector_clock v = v.vector_clock

let set_vector_clock v vc = {v with vector_clock = vc}

let timestamp v = v.timestamp

let init : string -> Hash.t -> t =
  fun b c ->
  { branch = b;
    version_num = 1;
    content_id = c;
    (* Note: Initially we may not have all the branches but
     * we should have the current branch in !_branch_list. *)
    vector_clock = List.map 
        (fun b' -> if b'<>b then (b',0) else (b,1)) !_branch_list;
    timestamp = Unix.gettimeofday ();
  }

(* (* Used by VersionGraph.hunt_for *)
let succeeds_or_eq : t -> t -> bool =
  fun v2 v1 ->
  branch v1 = branch v2 && v1.version_num <= v2.version_num
*)

let bump_vc vc branch = 
  List.map (fun (b,n) -> if b=branch then (b,n+1) else (b,n)) vc

let bump : t -> Hash.t -> t =
  fun v c ->
  { branch = v.branch;
    version_num = v.version_num + 1;
    content_id = c;
    vector_clock = bump_vc v.vector_clock v.branch;
    timestamp = Unix.gettimeofday ();
  }

let fork new_branch v = init new_branch (content_id v)

let fastfwd from_v into_v = bump into_v (content_id from_v)

let of_row : value array -> t =
  fun row ->
  { branch = get_string row.(0);
    version_num = get_int row.(1);
    content_id = Hash.from_string @@ get_string row.(2);
    vector_clock = vc_from_string @@ get_string row.(3);
    timestamp = float_of_string @@ get_string row.(4);
  }

let to_row : t -> value array =
  fun v ->
  [| Blob (big_of_string v.branch);
     Int (Int32.of_int v.version_num);
     Blob (Hash.big_string v.content_id);
     Blob (big_of_string @@ vc_to_string v.vector_clock);
     Blob (big_of_string @@ string_of_float v.timestamp)
  |]

let compare : t -> t -> int =
  fun v1 v2 ->
  let bc = String.compare v1.branch v2.branch in
  if bc = 0
  then let vc = Int.compare v1.version_num v2.version_num in
       if vc = 0
       then String.compare 
            (Hash.string v1.content_id) 
            (Hash.string v2.content_id)
       else vc
  else bc
