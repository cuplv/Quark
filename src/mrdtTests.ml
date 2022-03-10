(* Tests for the Rbset implementation of red-black tree sets *)
module Set = Mrbset.Make(SInt)

let s0 = Set.empty
let () = assert (Set.is_empty s0)

let s1 = Set.add 1 s0
let () = assert (not (Set.is_empty s1))

let s2 = Set.add 2 s0
let s12 = Set.union s1 s2
let s21 = Set.union s2 s1

let () = assert (Set.equal (Set.rem 9 s12) s12)
let () = assert (Set.equal s12 (Set.add 1 (Set.add 2 (Set.empty))))
let () = assert (Set.equal s12 s21)
let () = assert (not (Set.equal s1 s12))

let () = assert (Set.equal (Set.diff s12 s1) s2)
let () = assert (Set.equal (Set.diff s1 s1) s0)
let () = assert (Set.equal (Set.diff s1 s2) s1)

let s3 = Set.rem 1 s21
let s4 = Set.add 7 s21

let () = assert (Set.equal
                   (Set.merge s21 s3 s4)
                   (Set.add 7 (Set.rem 1 s21)))
let () = assert (Set.equal (Set.merge s4 s4 s4) s4)
let () = assert (Set.equal (Set.merge s21 s4 s4) s4)

let () = assert (Set.equal (Set.inter s12 s4) s12)
let () = assert (Set.elements s4 = [1;2;7])
let () = assert (Set.subset s12 s4)
let () = assert (not (Set.subset s4 s12))
let () = assert (Set.mem 7 s4)
let () = assert (not (Set.mem 7 s12))

(* Tests for the Rbmap impl of red-black tree maps *)
module Map = Mrbmap.Make(SInt)(SInt)

(* Check equality of all assocs, ignoring structure/balance differences in the tree representation *)
let (=~) = Map.equal Int.equal

let m0 = Map.empty

let m1 = Map.insert 2 3 m0

let () = assert (Map.find 2 m1 = 3)
let () = assert (not (Map.mem 3 m1))

let m1' = Map.insert 3 1 (Map.insert 2 4 m0)
let m2 = Map.insert 7 2 (Map.insert 2 5 m1)
let m3 = Map.remove 2 m1

let () = assert (Map.merge m0 m1 m1' = m1')
let () = assert (Map.merge m0 m1' m1 = Map.insert 3 1 m1)
let () = assert (Map.merge m1 m1 m2 = m2)
let () = assert (Map.merge m1 m2 m1 = m2)
let () = assert (Map.merge m1 m2 m3 = Map.remove 2 m2)
let () = assert (Map.merge m1 m3 m2 = Map.remove 2 m2)

let mi0 = Map.from_list [(6,1);(0,3)]
let () = assert (mi0 =~ Map.insert 6 1 (Map.insert 0 3 Map.empty))

let mi1 = Map.from_list [(0,5);(1,2);(5,3);(25,4)]
let mi2 = Map.update (fun _ -> 0) (fun n -> n + 1) mi1
let () = assert (mi2 =~ Map.from_list [(0,6);(1,3);(5,4);(25,5)])
let () = assert (Map.lookup 5 mi2 = Some(4))
let mi3 = Map.modify 5 (fun n -> n + 1) mi2
let () = assert (mi3 =~ Map.from_list [(0,6);(1,3);(5,5);(25,5)])
let () = assert (Map.select (fun _ -> 0) mi3 = [6;3;5;5])
let () = assert (Map.select (Int.compare 1) mi3 = [3])

(* Tests for Mlist *)
module List = Mlist.Make(SInt)

let l0 = []

let () = assert (List.is_empty l0)

let l1 = List.insert l0 0 4

let () = assert (l1 = [4])
let () = assert (List.insert l0 3 4 = [4])

let l2 = List.insert l1 1 5

let () = assert (l2 = [4;5])
let () = assert (List.insert l1 0 5 = [5;4])

let l3 = List.insert (List.insert l1 1 6) 0 8

let () = assert (List.merge l1 l2 l3 = [8;4;5;6])
let () = assert (List.merge l1 l3 l2 = [8;4;5;6])
