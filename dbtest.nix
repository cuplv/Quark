{ fetchFromGitHub, ocamlPackages, ocaml-scylla, ocaml-mrdt }:

with ocamlPackages;

let pname = "dbtest";

in

buildDunePackage rec {
  inherit pname;
  version = "0";
  src = ./dbtest;
  useDune2 = true;
  buildInputs = [
    ocaml-scylla
    # ocaml-mrdt
    # irmin
    # ppx_irmin
    # unix
  ];
}

