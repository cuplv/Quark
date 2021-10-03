(** The "head map" is a map of branch names to their current head
   version. This module has functions for creating and manipulating
   this map in the database. *)

(** A branch name. *)
type branch = Types.branch

(** Reference to head map in database. *)
type handle

(** [init name conn] creates a head map under the given name in the
   database, or returns an existing one under that name. *)
val init : string -> Scylla.conn -> (handle, string) result

(** List the names of branches in the head map. *)
val list_branches : handle -> branch list

(** Set a new head for a (possibly new) branch in the head map. Note
   that Version.t values contain their branch name, so there is no
   separate branch name argument to this function.

   [set h (Version.init "branch1" hash)] for example creates an
   initial version for "branch1" with content [hash], and sets
   branch1's head to this version in the head map.  *)
val set : handle -> Version.t -> unit

(** Get the head version of a given branch name, or return None if
   there is no entry for that branch. *)
val get : handle -> branch -> Version.t option
