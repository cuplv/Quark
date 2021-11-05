(*
 * Note: we are only defining list of atoms. A.t cannot be a linked data
 * structure.
 *)
module Make(A: Content.ATOM) (S: System.T): 
  Content.TYPE with type o = A.t list = struct

  module OM = Mlist.Make(A)

  module T = struct
    type t = 
      | Nil
      | Cons of A.t * Hash.t
    [@@deriving irmin]
    (*
     * This should generate a value t of type A.t Irmin.Type.t
     *)
  end

  module CStore = ContentStore.Make(T)

  include T

  type o = OM.t

  let rec to_adt t = match t with
    | Nil -> []
    | Cons(x, k) -> 
        (*let x = A.to_adt x_t in*)
        let xs_t = match CStore.get S.db k with
          | Some xs_t -> xs_t
          | None -> failwith "Invalid hash ref in a list!" in
        let xs = to_adt xs_t in
          x::xs

  let rec of_adt o = match o with
    | [] -> Nil
    | x::xs -> 
        let xs_t = of_adt xs in
        let hash = CStore.put S.db xs_t in
        (*let x_t = A.of_adt x in*)
          Cons (x, hash)

  let time s f v = 
    let t1 = Sys.time () in
    let v' = f v in
    let t2 = Sys.time () in
    let _ = Printf.printf "%s time: %fs\n" s (t2 -. t1) in
    let _ = flush stdout in
    v'

  let of_adt = time "of_adt" of_adt
  
  let to_adt = time "to_adt" to_adt

  let merge lca_t l1_t l2_t =
    of_adt @@
      OM.merge (to_adt lca_t) (to_adt l1_t) (to_adt l2_t)

  let o_merge = OM.merge
end


