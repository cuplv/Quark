type db = 
  {
    store_name: string;
    connection: Scylla.conn;
    consistency: Scylla.Protocol.consistency;
    (*
     * This is a hack. Clean solution is to have a separate
     * versionMap.
     *)
    mutable root: Version.t option;
  }

let make_db name conn = {store_name = name; 
                         connection = conn;
                         consistency = Scylla.Protocol.One;
                         root = None;}

let global_branch = "__system"

let global_lock_id = 10242021l

let set_consistency con db = 
  {db with consistency=con}

let reset_consistency = set_consistency Scylla.Protocol.One

let set_root db root = db.root <- Some root

module type T = sig
  val db: db
end
