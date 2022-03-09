module Make(Data: Content.ATOM) (S: System.T):
  Content.TYPE with type o = Mrbset.Make(Data).t = struct

  module Set = Mrbset.Make(Data)

  module T = struct
    type t = Set.t
    let t = Set.t
  end

  module CStore = ContentStore.Make(T)

  include T

  type o = t

  let o_merge = Set.merge

  let to_adt t = t
  let of_adt t = t
  let merge = o_merge
end
