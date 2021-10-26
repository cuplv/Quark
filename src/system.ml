type db = 
  {
    store_name: string;
    connection: Scylla.conn;
    consistency: Scylla.Protocol.consistency
  }

let make_db name conn = {store_name = name; 
                         connection = conn;
                         consistency = Scylla.Protocol.One}

let global_branch = "__system"

let global_lock_id = 10242021l

let set_consistency con db = 
  {db with consistency=con}

let reset_consistency = set_consistency Scylla.Protocol.One

module type T = sig
  val db: db
end
