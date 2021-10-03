(** This module provides the STORABLE interface for data store
   values. *)

(** A unique hash of a storable value. *)
type id = Digest.t

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
