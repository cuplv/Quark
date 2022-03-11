module Make(Key : Content.ATOM)(Value: Content.TYPE):
  Content.TYPE with type o = Mrbmap.Make(Key)(Value).t = struct

  module Map = Mrbmap.Make(Key)(Value)

  module T = struct
    type t = Map.t
    let t = Map.t
  end

  module CStore = ContentStore.Make(T)

  include T

  type o = t

  let o_merge = Map.merge

  let to_adt t = t
  let of_adt t = t
  let merge = o_merge
end
