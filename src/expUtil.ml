open Util
open MergeDB


let print_sync_res sync_res = 
  let$ () = Lwt_io.printf "Results of sync:\n" in
  let str = String.concat "; " @@
    List.map 
    (fun (b, res) -> match res with
      | Ok () -> b^" : ok"
      | Error (Blocked b') -> b^" : blocked by "^b'
      | Error Unrelated -> b^" : unrelated")
    sync_res in
  Lwt_io.printf "\t%s\n" str
