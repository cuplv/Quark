with import <nixpkgs> {};

rec {
  libcassandra = callPackage ./libcassandra.nix {};
  ocaml-scylla = callPackage ./ocaml-scylla.nix {};
  ocaml-mrdt = callPackage ./ocaml-mrdt.nix {
    inherit ocaml-scylla;
  };
  ocaml-cassandra = callPackage ./ocaml-cassandra.nix {
    inherit libcassandra;
  };
  dbtest = callPackage ./dbtest.nix {
    inherit ocaml-scylla ocaml-mrdt;
  };
}
