val init : string -> Scylla.conn -> (unit, string) result

val try_acquire: System.db -> string(*branch*) -> bool

val acquire: ?interval:float -> System.db -> string(*branch*) -> unit Lwt.t

val release: System.db -> string(*branch*) -> unit
