{ fetchFromGitHub, ocamlPackages, ocaml-scylla }:

with ocamlPackages;

let pname = "mergedb";

in

buildDunePackage rec {
  inherit pname;
  version = "0";
  src = ./src;
  useDune2 = true;
  buildInputs = [ ocaml-scylla ];
}
