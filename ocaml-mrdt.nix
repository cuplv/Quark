{ fetchFromGitHub, ocamlPackages, ocaml-scylla }:

with ocamlPackages;

let pname = "mrdt";

    repo = fetchFromGitHub {
      owner = "cuplv";
      repo = "ocaml-mrdt-v2";
      rev = "1f4e36c0a5fa324787a71da3827d47968f0249f5";
      sha256 = "1jzn13xmiwazbc4qmw7vwcjw7rf40p2r51jzmnznp9awin4rblb3";
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
  ];
}
