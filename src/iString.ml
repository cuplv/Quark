include SString

type o = string

let to_adt t = t

let of_adt o = o

let merge _ s1 _ = s1

let o_merge = merge
