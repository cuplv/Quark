open Scylla
open Scylla.Protocol
open Util

module CAS = struct
  let create_lock_table_query s = Printf.sprintf
    "create table if not exists tag.%s_lock(
       id int,
       branch text,
       primary key (id))"
    s

  (*
   * This is the CAS (LWT) query.
   *)
  let insert_lock_query s = Printf.sprintf
    "insert into tag.%s_lock(id, branch) 
     VALUES (?,?) if not exists"
    s

  let delete_lock_query s = Printf.sprintf
    "delete from tag.%s_lock where id = ?"
    s

  let update_lock_query s = Printf.sprintf
    "update tag.%s_lock set branch = ?
      where id = ? if id = ?"
    s

  let debug_query s = Printf.sprintf
    "select id, branch from tag.%s_lock"
    s


  let init s conn =
    let _ = query conn ~query:(create_lock_table_query s) () 
            |> Result.get_ok in
    Ok ()


  let try_acquire db b = 
    let res = query db.System.connection
                ~query:(insert_lock_query db.System.store_name)
                ~values:[|Int (System.global_lock_id); 
                          Varchar (Util.big_of_string b)|] 
                ~consistency: One () in
    begin
      match res with
      | Ok {values;_} -> (match values.(0).(0) with 
                            | Boolean b -> b
                            | _ -> failwith "Unexpected outcome \
                                  of conditional insert")
      | Error s -> failwith s
    end


  let rec acquire ?(interval=0.001) db b = 
    let$ status = Lwt.return @@ try_acquire db b in
    match status with
    | true -> let$ () = Lwt_io.printf "Acquired\n%!" in
              Lwt.return ()
    | false -> 
        let$ () = Lwt_io.printf "Retrying\n%!" in
        let$ () = Lwt_unix.sleep interval in
        let m = 1.0 +. (Random.float 1.0) in 
        acquire ~interval:(m *. interval) db b

  let acquire db b =  acquire db b

  let release db b = 
    let _ = ignore b in
    let res = query db.System.connection
                ~query:(delete_lock_query db.System.store_name)
                ~values:[|Int (System.global_lock_id)|] 
                ~consistency: Quorom () in
    begin
      match res with
      | Ok _ -> ()
      | Error s -> failwith s
    end
end

include CAS

(*
let create_lock_table_query s = Printf.sprintf
  "create table if not exists tag.%s_lock(
     id int,
     branch text,
     primary key (id))"
  s

let insert_lock_query s = Printf.sprintf
  "insert into tag.%s_lock(id, branch) 
   VALUES (?,?)"
  s

let read_lock_query s = Printf.sprintf
  "select branch from tag.%s_lock where id = ?"
  s


let init s conn =
  let _ = query conn ~query:(create_lock_table_query s) () 
          |> Result.get_ok in
  let b = !Config._branch in
  let _ = query conn 
              ~query:(insert_lock_query s)
              ~values:[|Int (System.global_lock_id); 
                        Varchar (Util.big_of_string b)|] 
              ~consistency:Quorom () |> Result.get_ok in
  Ok ()

let try_acquire db b = 
  let res = query db.System.connection
              ~query:(read_lock_query db.System.store_name)
              ~values:[|Int (System.global_lock_id)|] 
              ~consistency: Quorom () in
  begin
    match res with
    | Ok {values;_} -> (match values.(0).(0) with 
                          | Varchar s -> (Bigstringaf.to_string s) = b 
                          | _ -> failwith "Unexpected outcome \
                                of lock read")
    | Error s -> failwith s
  end


let rec acquire db b = 
  let _ = if !Config._branch = b then () 
          else failwith "Unexpected config" in
  let$ status = Lwt.return @@ try_acquire db b in
  match status with
  | true -> Lwt.return ()
  | false -> 
      let$ () = Lwt_unix.sleep Config.lock_interval in
      acquire db b

let release db b = 
  let _ = if !Config._branch = b then () 
          else failwith "Unexpected config" in
  let next_b = !Config._next_branch in
  let res = query db.System.connection
              ~query:(insert_lock_query db.System.store_name)
              ~values:[|Int (System.global_lock_id); 
                        Varchar (Util.big_of_string next_b)|] 
              ~consistency:Quorom () in
  begin
    match res with
    | Ok _ -> ()
    | Error s -> failwith s
  end
*)
