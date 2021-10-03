(** Functions for manipulating version values. These do not manipulate
   the version graph itself---that is handled by the VersionGraph
   module. *)

(** A unique version in a particular branch's history, which points to
   a particular content value by hash. *)
type t

(** Get the branch name of a version. *)
val branch : t -> string

(** Get the content_id of a version. *)
val content_id : t -> Content.id

(** [init b c] creates a new version with branch name b and content c,
   which is not a successor to any other version. *)
val init : string -> Content.id -> t

(** [bump v c] creates a successor version (with same branch name) to
   v, using c as the successor's content. *)
val bump : t -> Content.id -> t

(** [fork new_branch from_v] creates an initial version for
   new_branch which has the same content as from_v. *)
val fork : string -> t -> t

(** [fastfwd from_v into_v] creates a successor to into_v with the
   same content as from_v. *)
val fastfwd : t -> t -> t

(** [merge f lca_v from_v into_v] creates a successor to into_v with
   the content created by applying the 3-way merge function f to the
   contents of lca_v, from_v, and into_v. *)
val merge : Util.mergefun -> t -> t -> t -> (t, string) result

(** Convert a database row (Blob, Int, Blob) into a version. *)
val of_row : Scylla.Protocol.value array -> t

(** Convert a version into a database row (Blob, Int, Blob). *)
val to_row : t -> Scylla.Protocol.value array

(** Returns true if the first version is equal to the second or is a
   later version on the same branch as the second. *)
val succeeds_or_eq : t -> t -> bool

(** Compare two versions. *)
val compare : t -> t -> int
