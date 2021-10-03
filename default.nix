with import <nixpkgs> {};

rec {

  # Anmol's Cassandra/Scylla interface
  ocaml-scylla = callPackage ./ocaml-scylla.nix {};

  # Implementation of SC Merge rules
  mergedb = callPackage ./mergedb.nix {
    inherit ocaml-scylla;
  };
}
