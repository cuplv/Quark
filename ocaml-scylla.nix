{ fetchFromGitHub, ocamlPackages }:

with ocamlPackages;

let pname = "scylla";

    repo = fetchFromGitHub {
      owner = "gowthamk";
      repo = "ocaml-${pname}";
      rev = "65e87bdb61bde19fe2f50f77a6dc88c978445c68";
      sha256 = "1dn8xdjazkizk8ik8cg5kr6p9jjglw9j2w63iq5p26pkkb5fjfrh";
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
