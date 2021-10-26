val init : string -> Scylla.conn -> (unit, string) result

val try_acquire: System.db -> string(*branch*) -> (unit, string) result

val release: System.db -> string(*branch*) -> unit
