module Make(Key : Content.ATOM)(Value: Content.TYPE)(S: System.T):
  Content.TYPE with type o = Mrbmap.Make(Key)(Value).t = struct

  module OM = Mrbmap.Make(Key)(Value)

  module T = struct
    type t = 
      | B of Hash.t * (Key.t * Value.t) * Hash.t
      | R of Hash.t * (Key.t * Value.t) * Hash.t
      | E
    [@@deriving irmin]
  end

  module CStore = ContentStore.Make(T)

  include T

  type o = OM.t

  let rec to_adt t = match t with
    | E -> OM.Empty
    | B (hl, (k,v), hr) ->
        let l = CStore.get S.db hl |> Option.get |> to_adt in
        let r = CStore.get S.db hr |> Option.get |> to_adt in
        OM.Black (l,(k,v),r)
    | R (hl, (k,v), hr) ->
        let l = CStore.get S.db hl |> Option.get |> to_adt in
        let r = CStore.get S.db hr |> Option.get |> to_adt in
        OM.Red (l,(k,v),r)
      

  let rec of_adt o = match o with
    | OM.Empty -> E
    | OM.Black (l, (k,v), r) ->
        let hl = of_adt l |> CStore.put S.db in
        let hr = of_adt r |> CStore.put S.db in
        B (hl, (k,v), hr)
    | OM.Red (l, (k,v), r) ->
        let hl = of_adt l |> CStore.put S.db in
        let hr = of_adt r |> CStore.put S.db in
        R (hl, (k,v), hr)


  let merge lca_t l1_t l2_t =
    of_adt @@
      OM.merge (to_adt lca_t) (to_adt l1_t) (to_adt l2_t)

  let o_merge = OM.merge
end
