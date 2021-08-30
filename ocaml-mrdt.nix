{ fetchFromGitHub, ocamlPackages, ocaml-scylla }:

with ocamlPackages;

let pname = "mrdt";

    repo = fetchFromGitHub {
      owner = "anmolsahoo25";
      repo = "ocaml-mrdt-v2";
      rev = "6fc4f73d55eee3623238ebcb8df4ec6a997d78a4";
      sha256 = "1fr7gsm5zid8s7s9ffzg3mw9mzcwaxxbi3n12f069c0sgnancdg9";
    };

in

buildDunePackage rec {
  inherit pname;
  version = "0";
  src = repo;
  useDune2 = true;
  buildInputs = [
    ocaml-scylla
    irmin
    ppx_irmin
    # unix
  ];
}
