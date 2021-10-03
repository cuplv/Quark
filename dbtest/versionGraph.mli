(** A graph of versions, with their parent/child relationships as
   edges, stored in the database as an edgelist. *) 

(** Reference to the stored graph. *)
type handle

(** [init name conn] initializes a version graph in the database. Note
   that, if a graph with the same name is alreay there, this returns a
   reference to that graph. This will probably cause some problems if
   you create new versions using branch names that were already in the
   existing graph! *)
val init : string -> Scylla.conn -> (handle, string) result

(** [add_version h child parents] adds edges to the graph between the child version and each of the listed parent versions. *)
val add_version : handle -> Version.t -> Version.t list -> unit

(** Returns a list of parents of the given version. *)
val parents : handle -> Version.t -> Version.t list

(** Returns true if the first version is an ancestor of the second. *)
val is_ancestor : handle -> Version.t -> Version.t -> bool

(** Returns true if the two version are concurrent, meaning that
   neither is an ancestor of the other. *)
val is_concurrent : handle -> Version.t -> Version.t -> bool
