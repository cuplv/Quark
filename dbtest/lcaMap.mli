(** The "LCA map" is a map of branch pairs to their current LCA
   version. This module has functions for creating and manipulating
   this map in the database. *)

(** Reference to LCA map in database. *)
type handle

(** A branch name. *)
type branch = Types.branch

(** [init name conn] creates an LCA map under the given name in the
   database, or returns an existing one under that name. *)
val init : string -> Scylla.conn -> (handle, string) result

(** [set h "b1" "b2" v] sets v as the new LCA for branches "b1" and
   "b2". Note that the order of the branch arguments does not matter
   for this function. *)
val set : handle -> branch -> branch -> Version.t -> unit

(** Get the LCA version of the given branch pair, or return None if
   there is no entry for that branch. The order of branch arguments
   does not matter. *)
val get : handle -> branch -> branch -> Version.t option

(* (\** [get_all_for h "b1"] returns the list of b1's LCAs with all other
 *    branches. The list elements are pairs (b,v) where b' is the name of
 *    the other branch, and v is the LCA version between b1 and b. *\)
 * val get_all_for : handle -> branch -> (branch * version) list
 * 
 * (\** [get_all_for2 h "b1" "b2"] returns the list of b1's LCAs with all
 *    other branches, and also those for "b2". The list elements are
 *    pairs (b,v1,v2) where b is the name of the other branch, v1 is the
 *    LCA version between b1 and b, and v2 is the LCA version between b2
 *    and b. *\)
 * val get_all_for2 : handle -> branch -> branch -> (branch * version * version) list *)
