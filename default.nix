with import <nixpkgs> {};

rec {
  ocaml-scylla = callPackage ./ocaml-scylla.nix {};
  ocaml-mrdt = callPackage ./ocaml-mrdt.nix {
    inherit ocaml-scylla;
  };
}
