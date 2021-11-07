open Util
open MergeDB


let (>>=) = Lwt.bind

let print_sync_res = function [] -> Lwt_io.printf "No sync\n"
  | sync_res ->  
    let$ () = Lwt_io.printf "Results of sync:\n" in
    let str = String.concat "; " @@
      List.map 
      (fun (b, res) -> match res with
        | Ok () -> b^" : ok"
        | Error (Blocked b') -> b^" : blocked by "^b'
        | Error Unrelated -> b^" : unrelated")
      sync_res in
    Lwt_io.printf "\t%s\n" str

let fold f n b = 
  let rec fold_aux f i b = 
    if i >= n then b 
    else fold_aux f (i+1) @@ f i b in
  fold_aux f 0 b

let fail_if_error (r: ('a,string) result) : 'a = 
  match r with
  | Ok v -> v
  | Error s -> failwith s

let rec index_of a l = match l with
  | [] -> raise Not_found
  | x::_ when x=a -> 0
  | _::xs -> 1 + (index_of a xs)
