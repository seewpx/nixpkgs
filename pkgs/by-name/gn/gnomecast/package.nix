{
  stdenv,
  lib,
  python3Packages,
  fetchFromGitHub,
  gtk3,
  gobject-introspection,
  ffmpeg,
  wrapGAppsHook3,
}:

with python3Packages;
buildPythonApplication {
  pname = "gnomecast";
  version = "unstable-2022-04-23";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "keredson";
    repo = "gnomecast";
    rev = "d42d8915838b01c5cadacb322909e08ffa455d4f";
    sha256 = "sha256-CJpbBuRzEjWb8hsh3HMW4bZA7nyDAwjrERCS5uGdwn8=";
  };

  nativeBuildInputs = [ wrapGAppsHook3 ];
  propagatedBuildInputs = [
    pychromecast
    bottle
    pycaption
    paste
    html5lib
    pygobject3
    dbus-python
    gtk3
    gobject-introspection
  ];

  # NOTE: gdk-pixbuf setup hook does not run with strictDeps
  # https://nixos.org/manual/nixpkgs/stable/#ssec-gnome-hooks-gobject-introspection
  strictDeps = false;

  preFixup = ''
    gappsWrapperArgs+=(--prefix PATH : ${lib.makeBinPath [ ffmpeg ]})
  '';

  # no tests
  doCheck = false;

  meta = with lib; {
    description = "Native Linux GUI for Chromecasting local files";
    homepage = "https://github.com/keredson/gnomecast";
    license = with licenses; [ gpl3 ];
    broken = stdenv.hostPlatform.isDarwin;
    mainProgram = "gnomecast";
  };
}
