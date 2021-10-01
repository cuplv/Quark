type t
(** A unique version in a particular branch's history, which points to
   a particular content value by hash. *)

val branch : t -> string
(** Get the branch name of a version *)

val content_id : t -> Cas.content_id
(** Get the content_id of a version *)

val init : string -> Cas.content_id -> t
(** [init b c] creates a new version with branch name b and content c. *)

val bump : t -> Cas.content_id -> t
(** [bump v c] creates a successor version (with same branch name) to
   v, using c as the successor's content. *)

val fork : string -> t -> t
(** [fork new_branch from_v] creates an initial version for
   new_branch which has the same content as from_v. *)

val fastfwd : t -> t -> t
(** [fastfwd from_v into_v] creates a successor to into_v with the
   same content as from_v. *)

val merge : Util.mergefun -> t -> t -> t -> (t, string) result
(** [merge f lca_v from_v into_v] creates a successor to into_v with
   the content created by applying the 3-way merge function f to the
   contents of lca_v, from_v, and into_v. *)


val of_row : Scylla.Protocol.value array -> t
(** Convert a database row (Blob, Int, Blob) into a version. *)

val to_row : t -> Scylla.Protocol.value array
(** Convert a version into a database row (Blob, Int, Blob). *)

val compare : t -> t -> int
(** Compare two versions. *)

module Graph : sig
  type handle
  (** An open connection to a graph in a database. *)

  val init : string -> Scylla.conn -> (handle, string) result
  (** [init name conn] creates a database table using name, if it does
     not already exist. *)

  val add_version : handle -> t -> t list -> (unit, string) result
  (** [add_version h v ps] adds v as a new vertex in the graph, using
     existing vertexes ps as v's parents. *)

  val parents : handle -> t -> (t list, string) result
  (** [parents h v] gives a list of the direct parents of v in the
     graph. *)

  val is_ancestor : handle -> t -> t -> (bool, string) result
  (** [is_ancestor h v1 v2] checks whether v1 is an ancestor of v2. *)

end
