type db = 
  {
    store_name: string;
    connection: Scylla.conn
  }

let make_db name conn = {store_name = name; connection=conn}

module type T = sig
  val db: db
end
