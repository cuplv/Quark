{ stdenv, ocamlPackages, libcassandra }:

with ocamlPackages;

let src = ../irmin-scylla/irmin-master;

in

buildDunePackage {
  inherit src;
  pname = "irmin-scylla";
  version = "0";
  useDune2 = true;
  buildInputs = [ libcassandra lwt ];
}
