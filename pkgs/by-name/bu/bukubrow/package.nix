{
  lib,
  rustPlatform,
  fetchFromGitHub,
  sqlite,
}:
let

  manifest = {
    description = "Bukubrow extension host application";
    name = "com.samhh.bukubrow";
    path = "@out@/bin/bukubrow";
    type = "stdio";
  };

in
rustPlatform.buildRustPackage rec {
  pname = "bukubrow-host";
  version = "5.4.0";

  src = fetchFromGitHub {
    owner = "SamHH";
    repo = "bukubrow-host";
    rev = "v${version}";
    sha256 = "sha256-xz5Agsm+ATQXXgpPGN4EQ00i1t8qUlrviNHauVdCu4U=";
  };

  cargoHash = "sha256-mCPJE9WW14NtahbMnDcE+0xXl5w25dzerPy3wv78l20=";

  buildInputs = [ sqlite ];

  passAsFile = [
    "firefoxManifest"
    "chromeManifest"
  ];
  firefoxManifest = builtins.toJSON (
    manifest
    // {
      allowed_extensions = [ "bukubrow@samhh.com" ];
    }
  );
  chromeManifest = builtins.toJSON (
    manifest
    // {
      allowed_origins = [ "chrome-extension://ghniladkapjacfajiooekgkfopkjblpn/" ];
    }
  );
  postBuild = ''
    substituteAll $firefoxManifestPath firefox.json
    substituteAll $chromeManifestPath chrome.json
  '';
  postInstall = ''
    install -Dm0644 firefox.json $out/lib/mozilla/native-messaging-hosts/com.samhh.bukubrow.json
    install -Dm0644 chrome.json $out/etc/chromium/native-messaging-hosts/com.samhh.bukubrow.json
  '';

  meta = with lib; {
    description = "WebExtension for Buku, a command-line bookmark manager";
    homepage = "https://github.com/SamHH/bukubrow-host";
    license = licenses.gpl3;
    maintainers = [ ];
    mainProgram = "bukubrow";
  };
}
