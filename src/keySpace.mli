(** Functions to create the keyspaces for various database tables. *)

(** Create the keyspace for the "tag store" tables, including the
   version graph, the head map, and the LCA map. Any error that arises
   from the database interface will be returned as an Error result.

   This should be called before calling [init] from the modules for
   those stores. *)
val create_tag_ks : Scylla.conn -> (unit, string) result

(** Delete the tag store keyspace. This is useful for setting up a
   clean experiment. *)
val delete_tag_ks : Scylla.conn -> (unit, string) result

(** Create the keyspace for the immutable content-addressed store
   table. Any error that arises from the database interface will be
   returned as an Error result.

   This should be called before calling [init] from the ContentStore
   module. *)
val create_content_ks : Scylla.conn -> (unit, string) result

(** Delete the content store keyspace. This will usually not be
   necessary since the content store only contains immutable data that
   can't contradict later values. *)
val delete_content_ks : Scylla.conn -> (unit, string) result
