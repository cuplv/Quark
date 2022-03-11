type t = int32

type o = t

let t = Irmin.Type.int32

let compare = Int32.compare

let merge lca v1 v2 =
  let (+) = Int32.add in
  let (-) = Int32.sub in
  lca + (v1 - lca) + (v2 - lca)

let to_adt t = t
let of_adt t = t
let o_merge = merge
