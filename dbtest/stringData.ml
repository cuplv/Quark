(** An implementation of MergeDB.Data (and Content.STORABLE) for
   strings. *)

type t = string
type data = t
let hash s = Digest.string s
let to_big = Util.big_of_string
let from_big = Bigstringaf.to_string

(** A simple merge function for append-only strings. Assume that the
   LCA is a prefix of both strings (hence append-only), and then
   append the remainder of v1, and then the remainder of v2.

   For example, [str_merge "A" "AB" "AC" = "ABC"].

   If the new versions are not both longer than or equal to the LCA,
   then the second version is taken as the whole merged value.

  For example, [str_merge "AB" "ABC" "D" = "D"]. *)
let merge3 lca_s v1_s v2_s = 
  if String.length lca_s <= String.length v1_s
     && String.length lca_s <= String.length v2_s
  then
    let l = String.length lca_s in
    let d1 = String.sub v1_s l (String.length v1_s - l) in
    let d2 = String.sub v2_s l (String.length v2_s - l) in
    lca_s ^ d1 ^ d2
  else
    v2_s
