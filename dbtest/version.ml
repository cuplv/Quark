open Util

type value = Scylla.Protocol.value

type t =
  { branch : string;
    version_num : int;
    content_id : Content.id;
  }

let branch v = v.branch

let content_id v = v.content_id

let version_num v = v.version_num

let init : string -> Content.id -> t =
  fun b c ->
  { branch = b;
    version_num = 0;
    content_id = c
  }

let succeeds_or_eq : t -> t -> bool =
  fun v2 v1 ->
  branch v1 = branch v2 && v1.version_num <= v2.version_num

let bump : t -> Content.id -> t =
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
