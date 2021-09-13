let () = Printf.printf "%s" Cas.test


(* module Set = Mrdt.Mset.Make (struct type t = int [@@deriving irmin] let compare = compare end)
 * 
 * let conn = Scylla.connect ~ip:"127.0.0.1" ~port:9042 |> Result.get_ok
 * 
 * (\* Set up replica 0 *\)
 * 
 * let set0 = Set.init 0 "set0" [conn]
 * let e0 = 5
 * let () = Set.add e0 set0
 * let x0 = Set.commit set0
 * let () = if Set.mem e0 set0
 *          then Printf.printf "R0 added element %d.\n" e0
 *          else Printf.printf "R0 failed to add element?\n"
 * let () = Printf.printf "R0 says min element is %d.\n" (Set.min_elt set0)
 * 
 * (\* Set up replica 1 *\)
 * 
 * let set1 = Set.init 1 "set0" [conn]
 * let e1 = 7
 * let () = Set.add e1 set1
 * let x1 = Set.commit set1
 * let () = if Set.mem e1 set1
 *          then Printf.printf "R1 added element %d.\n" e1
 *          else Printf.printf "R1 failed to add element?\n"
 * let () = Printf.printf "R1 says min element is %d.\n" (Set.min_elt set1)
 * 
 * (\* Merge *\)
 * 
 * (\* 3-way merge with version x0 at replica 1 *\)
 * let x = Set.merge x0 1 set1
 * let () = Printf.printf "After merge, R1 says min element is %d.\n" (Set.min_elt set1) *)
