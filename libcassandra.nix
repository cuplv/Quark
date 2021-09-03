{ stdenv, fetchFromGitHub, cmake, libuv, kerberos, openssl, zlib }:

let src = fetchFromGitHub {
      owner = "datastax";
      repo = "cpp-driver";
      rev = "2.16.0";
      sha256 = "1pjqw1jsys0i67x7c7pmc1r4li2fkj1w8xa31aqx5kkcmm45d7kk";
    };

in

stdenv.mkDerivation {
  inherit src;
  name = "libcassandra";
  nativeBuildInputs = [ cmake ];
  buildInputs = [ libuv kerberos openssl zlib ];

  # Needed for the cmake config to find libuv
  LIBUV_ROOT_DIR = libuv;
}
