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

  let merge lca_t l1_t l2_t =
    of_adt @@
      OM.merge (to_adt lca_t) (to_adt l1_t) (to_adt l2_t)

end


