type t

val t : t Irmin.Type.t

val digest_string: string -> t

val digest_big_string: Bigstringaf.t -> t

val string: t -> string

val big_string: t -> Bigstringaf.t

val from_string: string -> t

val equal: t -> t -> bool
