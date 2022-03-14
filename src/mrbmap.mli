module Make (Key : Content.ATOM)(Value : Content.TYPE) : sig
  type t =
    | Black of t * (Key.t * Value.t) * t
    | Red of t * (Key.t * Value.t) * t
    | Empty

  (** The empty map *)
  val empty : t

  val is_empty : t -> bool

  val from_list : (Key.t * Value.t) list -> t

  val insert : Key.t -> Value.t -> t -> t

  (** Apply the function to the keyed value, if it exists *)
  val modify : Key.t -> (Value.t -> Value.t) -> t -> t

  val find : Key.t -> t -> Value.t

  val lookup : Key.t -> t -> Value.t option

  val remove : Key.t -> t -> t

  (** Check if a key is in the map *)
  val mem : Key.t -> t -> bool

  val iter : (Key.t -> Value.t -> unit) -> t -> unit

  val map : (Value.t -> Value.t) -> t -> t

  val mapi : (Key.t -> Value.t -> Value.t) -> t -> t

  val fold : (Key.t -> Value.t -> Value.t -> Value.t) -> t -> Value.t -> Value.t

  val compare : (Value.t -> Value.t -> int) -> t -> t -> int

  val equal : (Value.t -> Value.t -> bool) -> t -> t -> bool

  val update : (Key.t -> int) -> (Value.t -> Value.t) -> t -> t

  val select : (Key.t -> int) -> t -> Value.t list

  val keys : t -> Key.t list

  val choose: t -> Key.t

  (** [merge lca v1 v2] performs three-way merge on [v1] and [v2],
     using [lca] as the common ancestor **)
  val merge : t -> t -> t -> t
end
