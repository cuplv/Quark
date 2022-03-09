module Make (Data : Content.ATOM) : sig
  type t
  val t : t Irmin.Type.t

  (** The empty set *)
  val empty : t

  val is_empty : t -> bool

  (** Check if an element is a member of the set *)
  val mem : Data.t -> t -> bool

  val add : Data.t -> t -> t

  (** Remove an element from the set, or return the set unchanged if
     the element did not exist *)
  val rem : Data.t -> t -> t

  (** Set union *)
  val union : t -> t -> t

  (** Set intersection *)
  val inter : t -> t -> t

  (** [diff s1 s2] gives the elements of [s1] which are not in [s2] *)
  val diff : t -> t -> t

  val equal : t -> t -> bool

  (** [subset s1 s2] checks that [s1] is a subset of [s2] *)
  val subset : t -> t -> bool

  (** Get list of elements, ordered least to greatest *)
  val elements : t -> Data.t list

  (** Number of elements in the set **)
  val size : t -> int

  (** Number on nodes making up the tree-representation of the set,
     including empty leaf nodes **)
  val node_count : t -> int

  (** [merge lca v1 v2] performs three-way merge on [v1] and [v2],
     using [lca] as the common ancestor **)
  val merge : t -> t -> t -> t
end
