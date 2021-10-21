(** This module provides the STORABLE interface for data store
   values. *)

(*
 * Comparable types
 *)
module type COMPARABLE = sig
  type t
  val compare: t -> t -> int
end

(*
 * Serializable types
 *)
module type SERIALIZABLE = sig

  (** Type of data *)
  type t

  (** Type representation of data *)
  val t : t Irmin.Type.t
end

(*
 * Type of atoms in stored data structures
 *)
module type ATOM = sig
  type t
  include SERIALIZABLE with type t := t
  include COMPARABLE with type t := t
end

(*
 * The interface we need content values to implement.
 *)
module type TYPE = sig

  include SERIALIZABLE
  
  (** Original (Ocaml) type *)
  type o

  (** From store type to heap type *)
  val to_adt: t -> o
  
  (** From heap type to store type *)
  val of_adt: o -> t

  (** 3-way merge function *)
  val merge: t -> t -> t -> t
end
