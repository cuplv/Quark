{ fetchFromGitHub, ocamlPackages }:

with ocamlPackages;

let pname = "scylla";

    repo = fetchFromGitHub {
      owner = "anmolsahoo25";
      repo = "ocaml-${pname}";
      rev = "1781f065d913d629052fdf06605de1a727cf5601";
      sha256 = "05yjhn9hvfjnmkc2m1xb2xch54p8jqy6jyz6qak3rpyrfcdxk778";
    };

in

buildDunePackage rec {
  inherit pname;
  version = "0";
  src = repo;
  useDune2 = true;
  buildInputs = [
  ];
  propagatedBuildInputs = [
    angstrom
    faraday
    lwt
    ppx_deriving
    ppxlib
    uutf
  ];
}
