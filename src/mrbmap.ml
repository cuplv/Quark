(* Modified from code under following license:
 * 
 * Copyright (c) 2007, Benedikt Meurer <benedikt.meurer@googlemail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 *)

module Make (Key : Content.ATOM)(Value : Content.TYPE) = struct
  type key = Key.t
  type value = Value.t

  type t =
    | Black of t * (Key.t * Value.t) * t
    | Red of t * (Key.t * Value.t) * t
    | Empty
  [@@deriving irmin]

  type enum =
    | End
    | More of key * value * t * enum

  let rec enum m e =
    match m with
      | Empty -> e
      | Black(l, (k, x), r) | Red(l, (k, x), r) -> enum l (More(k, x, r, e))

  let rec keys = function
    | Empty -> []
    | Black(l, (k, _), r) | Red(l, (k, _), r) -> keys l @ (k :: keys r)

  let blackify = function
    | Red(l, (k, x), r) -> Black(l, (k, x), r), false
    | m -> m, true

  let empty = Empty

  let is_empty = function
    | Empty -> true
    | _ -> false

  let balance_left l kx x r =
    match l, kx, x, r with
      | Red(Red(a, (kx, x), b), (ky, y), c), kz, z, d
      | Red(a, (kx, x), Red(b, (ky, y), c)), kz, z, d ->
          Red(Black(a, (kx, x), b), (ky, y), Black(c, (kz, z), d))
      | l, kx, x, r ->
          Black(l, (kx, x), r)

  let balance_right l kx x r =
    match l, kx, x, r with
      | a, kx, x, Red(Red(b, (ky, y), c), (kz, z), d)
      | a, kx, x, Red(b, (ky, y), Red(c, (kz, z), d)) ->
          Red(Black(a, (kx, x), b), (ky, y), Black(c, (kz, z), d))
      | l, kx, x, r ->
          Black(l, (kx, x), r)

  let add kx x m =
    let rec add_aux = function
      | Empty ->
          Red(Empty, (kx, x), Empty)
      | Red(l, (ky, y), r) ->
          let c = Key.compare kx ky in
            if c < 0 then
              Red(add_aux l, (ky, y), r)
            else if c > 0 then
              Red(l, (ky, y), add_aux r)
            else
              Red(l, (kx, x), r)
      | Black(l, (ky, y), r) ->
          let c = Key.compare kx ky in
            if c < 0 then
              balance_left (add_aux l) ky y r
            else if c > 0 then
              balance_right l ky y (add_aux r)
            else
              Black(l, (kx, x), r)
    in fst (blackify (add_aux m))

  let insert = add

  let from_list l =
    let f t (k,v) = insert k v t in
    List.fold_left f empty l

  let rec find k = function
    | Empty ->
        raise Not_found
    | Red(l, (kx, x), r)
    | Black(l, (kx, x), r) ->
        let c = Key.compare k kx in
          if c < 0 then 
            find k l
          else if c > 0 then 
            find k r
          else x

  let rec modify k f = function
    | Empty -> Empty
    | Red(l, (kx, x), r) ->
       let c = Key.compare k kx in
       if c < 0 then
         Red(modify k f l, (kx,x), r)
       else if c > 0 then
         Red(l, (kx,x), modify k f r)
       else
         Red(l, (kx, f x), r)
    | Black(l, (kx, x), r) ->
       let c = Key.compare k kx in
       if c < 0 then
         Black(modify k f l, (kx,x), r)
       else if c > 0 then
         Black(l, (kx,x), modify k f r)
       else
         Black(l, (kx, f x), r)

  let unbalanced_left = function
    | Red(Black(a, (kx, x), b), (ky, y), c) ->
        balance_left (Red(a, (kx, x), b)) ky y c, false
    | Black(Black(a, (kx, x), b), (ky, y), c) ->
        balance_left (Red(a, (kx, x), b)) ky y c, true
    | Black(Red(a, (kx, x), Black(b, (ky, y), c)), (kz, z), d) ->
        Black(a, (kx, x), balance_left (Red(b, (ky, y), c)) kz z d), false
    | _ ->
        assert false

  let unbalanced_right = function
    | Red(a, (kx, x), Black(b, (ky, y), c)) ->
        balance_right a kx x (Red(b, (ky, y), c)), false
    | Black(a, (kx, x), Black(b, (ky, y), c)) ->
        balance_right a kx x (Red(b, (ky, y), c)), true
    | Black(a, (kx, x), Red(Black(b, (ky, y), c), (kz, z), d)) ->
        Black(balance_right a kx x (Red(b, (ky, y), c)), (kz, z), d), false
    | _ ->
        assert false

  let rec remove_min = function
    | Empty
    | Black(Empty, (_, _), Black(_)) ->
        assert false
    | Black(Empty, (kx, x), Empty) ->
        Empty, kx, x, true
    | Black(Empty, (kx, x), Red(l, (ky, y), r)) ->
        Black(l, (ky, y), r), kx, x, false
    | Red(Empty, (kx, x), r) ->
        r, kx, x, false
    | Black(l, (kx, x), r) ->
        let l, ky, y, d = remove_min l in
        let m = Black(l, (kx, x), r) in
          if d then
            let m, d = unbalanced_right m in m, ky, y, d
          else
            m, ky, y, false
    | Red(l, (kx, x), r) ->
        let l, ky, y, d = remove_min l in
        let m = Red(l, (kx, x), r) in
          if d then
            let m, d = unbalanced_right m in m, ky, y, d
          else
            m, ky, y, false

  let remove k m =
    let rec remove_aux = function
      | Empty ->
          Empty, false
      | Black(l, (kx, x), r) ->
          let c = Key.compare k kx in
            if c < 0 then
              let l, d = remove_aux l in
              let m = Black(l, (kx, x), r) in
                if d then unbalanced_right m else m, false
            else if c > 0 then
              let r, d = remove_aux r in
              let m = Black(l, (kx, x), r) in
                if d then unbalanced_left m else m, false
            else
              begin match r with
                | Empty ->
                    blackify l
                | _ ->
                    let r, kx, x, d = remove_min r in
                    let m = Black(l, (kx, x), r) in
                      if d then unbalanced_left m else m, false
              end
      | Red(l, (kx, x), r) ->
          let c = Key.compare k kx in
            if c < 0 then
              let l, d = remove_aux l in
              let m = Red(l, (kx, x), r) in
                if d then unbalanced_right m else m, false
            else if c > 0 then
              let r, d = remove_aux r in
              let m = Red(l, (kx, x), r) in
                if d then unbalanced_left m else m, false
            else
              begin match r with
                | Empty ->
                    l, false
                | _ ->
                    let r, kx, x, d = remove_min r in
                    let m = Red(l, (kx, x), r) in
                      if d then unbalanced_left m else m, false
              end
    in fst (remove_aux m)

  let rec mem k = function
    | Empty ->
        false
    | Red(l, (kx, _), r)
    | Black(l, (kx, _), r) ->
        let c = Key.compare k kx in
          if c < 0 then mem k l
          else if c > 0 then mem k r
          else true

  let lookup k t =
    if mem k t then
      Some(find k t)
    else
      None

  let rec iter f = function
    | Empty -> ()
    | Red(l, (k, x), r) | Black(l, (k, x), r) -> iter f l; f k x; iter f r

  let rec map f = function
    | Empty -> Empty
    | Red(l, (k, x), r) -> Red(map f l, (k, f x), map f r)
    | Black(l, (k, x), r) -> Black(map f l, (k, f x), map f r)

  let rec mapi f = function
    | Empty -> Empty
    | Red(l, (k, x), r) -> Red(mapi f l, (k, f k x), mapi f r)
    | Black(l, (k, x), r) -> Black(mapi f l, (k, f k x), mapi f r)

  let rec fold f m accu =
    match m with
      | Empty -> accu
      | Red(l, (k, x), r) | Black(l, (k, x), r) -> fold f r (f k x (fold f l accu))

  let compare cmp m1 m2 =
    let rec compare_aux e1 e2 =
      match e1, e2 with
        | End, End ->
            0
        | End, _ ->
            -1
        | _, End ->
            1
        | More(k1, x1, r1, e1), More(k2, x2, r2, e2) ->
            let c = Key.compare k1 k2 in
              if c <> 0 then c
              else
                let c = cmp x1 x2 in
                  if c <> 0 then c
                  else compare_aux (enum r1 e1) (enum r2 e2)
    in compare_aux (enum m1 End) (enum m2 End)

  let equal cmp m1 m2 =
    let rec equal_aux e1 e2 =
      match e1, e2 with
        | End, End ->
            true
        | End, _
        | _, End ->
            false
        | More(k1, x1, r1, e1), More(k2, x2, r2, e2) ->
            (Key.compare k1 k2 = 0
                && cmp x1 x2
                && equal_aux (enum r1 e1) (enum r2 e2))
    in equal_aux (enum m1 End) (enum m2 End)

  let rec update sigf updf t = match t with
    | Empty -> Empty
    | Red(l, (k, v), r) 
      when sigf k > 0 -> Red(update sigf updf l, (k, v), r)
    | Black(l, (k, v), r) 
      when sigf k > 0 -> Black(update sigf updf l, (k, v), r)
    | Red(l, (k, v), r) 
      when sigf k < 0 -> Red(l, (k, v), update sigf updf r)
    | Black(l, (k, v), r) 
      when sigf k < 0 -> Black(l, (k, v), update sigf updf r)
    | Red(l, (k, v), r) 
      when sigf k = 0 -> Red(update sigf updf l, 
                             (k, updf v),
                             update sigf updf r)
    | Black(l, (k, v), r) 
      when sigf k = 0 -> Black(update sigf updf l, 
                               (k, updf v),
                               update sigf updf r)
    | _ -> failwith "Rbmap.update.exhaustiveness"

  let rec select sigf t = match t with
    | Empty -> []
    | Red(l, (k, _), _) | Black(l, (k, _), _)
      when sigf k > 0 -> select sigf l
    | Red(_, (k, _), r) | Black(_, (k, _), r) 
      when sigf k < 0 -> select sigf r
    | Red(l, (k, v), r) 
      when sigf k = 0 -> (select sigf l)@(v::(select sigf r))
    | Black(l, (k, v), r) 
      when sigf k = 0 -> (select sigf l)@(v::(select sigf r))
    | _ -> failwith "Rbmap.select.exhaustiveness"

  let rec height_est = function
    | Empty -> 0
    | Black (l,_,r) | Red (l,_,r) -> 
      if Random.int 2 = 0 then 1 + height_est l 
      else 1+ height_est r

  let choose t = 
    let rec choose_aux h rand t = match t with
      | Empty -> raise Not_found
      | Black (Empty,(k,_), Empty) 
      | Red (Empty, (k,_), Empty) -> k
      | Black (lt, (k,_), rt) 
      | Red (lt, (k,_), rt) ->
        if rand < (1 lsl (h+1))  then k
        else begin 
          let child = match lt,rt with
            | Empty,_ -> rt
            | _,Empty -> lt
            | _,_ -> if Random.int 2 = 0 then lt else rt in
          choose_aux (h+1) rand child
        end in
    let eht = height_est t in
    let esize = 1 lsl (min eht 30) in
    let rand = (Random.int esize) + 1 in
    choose_aux 0 rand t

  let merge lca v1 v2 =
    let ks = List.sort_uniq (Key.compare) (keys v1 @ keys v2) in
    let f t k = match (lookup k lca, lookup k v1, lookup k v2) with
      (* If k is present in all three, do a merge.  I'm assuming that
         if all are equal, result of merge is also equal *)
      | (Some(a_lca), Some(a_v1), Some(a_v2)) ->
         insert k (Value.merge a_lca a_v1 a_v2) t
      (* If k is dropped by either new version, drop it *)
      | (Some(_), None, _) -> t
      | (Some(_), _, None) -> t
      (* If k is added by either version, keep it.  If added by both,
         arbitrarily take the v2 value *)
      | (_, _, Some(a_v2)) -> insert k a_v2 t
      | (_, Some(a_v1), _) -> insert k a_v1 t
      | (None,None,None) -> failwith "Rbmap.merge.exhaustiveness"
    in
    List.fold_left f empty ks
end
