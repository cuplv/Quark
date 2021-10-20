(** This module provides the STORABLE interface for data store
   values. *)

(** A unique hash of a storable value. *)
type id = Hash.t

(** A STORABLE value can be hashed to get a content_id and can be
   converted to and from the Bigstringaf.t type. These features allow
   it to be stored in the immutable content-addressed store. *)
module type STORABLE = sig

  (** The type of values that can be stored. *)
  type data
  
  (** [hash v] generates a unique content_id from v. *)
  val hash : data -> id

  (** Convert to bigstring. *)
  val to_big : data -> Bigstringaf.t
  
  (** Convert from bigstring. *)
  val from_big : Bigstringaf.t -> data
end
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
  val to_o: Util.table_handle -> t -> o
  
  (** From heap type to store type *)
  val to_t: Util.table_handle -> o -> t

  (** 3-way merge function *)
  val merge: Util.table_handle -> t -> t -> t -> t
end
