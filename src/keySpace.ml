open Util

let create_tag_ks_query = Printf.sprintf
  "create keyspace if not exists tag
   with replication = {
   'class':'SimpleStrategy',
   'replication_factor':1};"

let drop_tag_ks_query = Printf.sprintf
  "drop keyspace if exists tag"

let create_content_ks_query = Printf.sprintf
  "create keyspace if not exists content
   with replication = {
   'class':'SimpleStrategy',
   'replication_factor':1};"

let drop_content_ks_query = Printf.sprintf
  "drop keyspace if exists content"

let create_tag_ks conn =
  let* _ = Scylla.query conn ~query:create_tag_ks_query ()
  in
  Ok ()

let create_content_ks conn =
  let* _ = Scylla.query conn ~query:create_content_ks_query ()
  in
  Ok ()

let delete_tag_ks conn =
  let* _ = Scylla.query conn ~query:drop_tag_ks_query ()
  in
  Ok ()

let delete_content_ks conn =
  let* _ = Scylla.query conn ~query:drop_content_ks_query ()
  in
  Ok ()
