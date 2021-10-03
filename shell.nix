with import <nixpkgs> {};

with import ./default.nix;

# mkShell {
#   buildInputs = with ocamlPackages; [
#     dune_2
#     ocaml
#     ocaml-scylla
#     ocaml-mrdt
#   ];
# }

mergedb
