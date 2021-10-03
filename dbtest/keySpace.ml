open Util

let create_tag_ks_query = Printf.sprintf
  "create keyspace if not exists tag
   with replication = {
   'class':'SimpleStrategy',
   'replication_factor':1};"

let create_content_ks_query = Printf.sprintf
  "create keyspace if not exists content
   with replication = {
   'class':'SimpleStrategy',
   'replication_factor':1};"

let create_tag_ks conn =
  let* _ = Scylla.query conn ~query:create_tag_ks_query ()
  in
  Ok ()

let create_content_ks conn =
  let* _ = Scylla.query conn ~query:create_content_ks_query ()
  in
  Ok ()
