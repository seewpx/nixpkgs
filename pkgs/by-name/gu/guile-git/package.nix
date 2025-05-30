{
  lib,
  stdenv,
  fetchFromGitLab,
  guile,
  libgit2,
  scheme-bytestructures,
  autoreconfHook,
  pkg-config,
  texinfo,
}:

stdenv.mkDerivation rec {
  pname = "guile-git";
  version = "0.9.0";

  src = fetchFromGitLab {
    owner = "guile-git";
    repo = "guile-git";
    rev = "v${version}";
    hash = "sha256-lFBoA1VBJRHcZkP3h2gnlXQrMjDFWS4jl9RlF8VVf/Q=";
  };

  patches = [
    ./0001-structs-Omit-free-field-from-config-entry-on-libgit2.patch
    ./0002-structs-Add-update-refs-field-to-remote-callbacks-on.patch
  ];

  strictDeps = true;
  nativeBuildInputs = [
    autoreconfHook
    guile
    pkg-config
    texinfo
  ];
  buildInputs = [
    guile
  ];
  propagatedBuildInputs = [
    libgit2
    scheme-bytestructures
  ];
  doCheck = true;
  makeFlags = [ "GUILE_AUTO_COMPILE=0" ];

  enableParallelBuilding = true;

  # Skipping proxy tests since it requires network access.
  postConfigure = ''
    sed -i -e '94i (test-skip 1)' ./tests/proxy.scm
  '';

  __darwinAllowLocalNetworking = true;

  meta = with lib; {
    description = "Bindings to Libgit2 for GNU Guile";
    homepage = "https://gitlab.com/guile-git/guile-git";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ ethancedwards8 ];
    platforms = guile.meta.platforms;
  };
}
