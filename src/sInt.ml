type t = int

type o = t

let t = Irmin.Type.int

let compare = Int.compare

let merge lca v1 v2 = lca + (v1 - lca) + (v2 - lca)

let to_adt t = t
let of_adt t = t
let o_merge = merge
