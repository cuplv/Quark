(** Database using git-like merges, maintaining convergence among
   branches by enforcing a single-LCA invariant. *)

(** A branch name. *)
type branch = Types.branch

(** A reason for pull failure. [Unrelated] means that the two branches
   did not descend from the same root branch and thus did not have an
   LCA. [Blocked "b"] means that the two branches' LCAs with third
   branch "b" were concurrent. *)
type pull_error = Unrelated | Blocked of branch

(** A merge database for a given Data type of values. *)

module Make (Data : Content.TYPE) : sig

  (** [init name conn] creates a backed database, or returns an
     existing one if the name is alreay used.

     Any errors thrown by the backing database interface will be
     returned as an Error case of Result. *)
  val init : System.db -> (unit, string) result

  (** [fresh_init name conn] creates a backed database, removing the
     tag store associated with any pre-existing database.

     Any errors thrown by the backing database interface will be
     returned as an Error case of Result. *)
  val fresh_init : System.db -> (unit, string) result
  
  (** [commit h "b" d] commits a new version on branch "b" with
     content d, or returns None if "b" did not exist. *)
  val commit : System.db -> branch -> Data.o -> unit option
  
  (** [fork h "old" "new"] creates branch "new" as a fork of "old",
     returning Some ("new"). If branch "old" did not exist, None is
     returned and branch "new" is not created.
  
     WARNING: if a branch with the name "new" already exists, other
     branches related to the old "new" will become confused. *)
  val fork : System.db -> branch -> branch -> branch option
  
  (** [new_root h "b" d] creates a new branch "b" not related to any
     other, and gives the new branch an initial version with content
     d.
  
     WARNING: if a branch with the name "b" already exists, other
     branches related to the old "b" will become confused. *)
  val new_root : System.db -> branch -> Data.o -> unit
  
  (** Get the latest value of the branch, or return None if the branch
     does not exist. *)
  val read : System.db -> branch -> Data.o option
  
  (** [pull h "from" "into"] updates branch "into" with the latest
     version of branch "from", using either a fast-forward or merge as
     appropriate.
  
     If this pull fails, a pull_error is returned indicating the
     reason. *)
  val pull : System.db -> branch -> branch -> (unit, pull_error) result

  val sync : System.db -> branch 
              -> (branch * (unit, pull_error) result) list Lwt.t

  (** Print information from the database tables for debugging. *)
  val debug_dump : System.db -> unit
end
