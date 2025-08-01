{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  curl,
  libgit2,
  openssl,
}:
let
  version = "0.16.1";
  src = fetchFromGitHub {
    owner = "google";
    repo = "cargo-raze";
    rev = "v${version}";
    hash = "sha256-dn1MrF+FYBG+vD5AfXCwmzskmKK/TXArnMWW2BAfFFQ=";
  };
in
rustPlatform.buildRustPackage {
  pname = "cargo-raze";
  inherit src version;

  sourceRoot = "${src.name}/impl";

  # Make it build on Rust >1.76. Since upstream is unmaintained,
  # there's no counting on them to fix this any time soon...
  # See #310673 and #310125 for similar fixes
  cargoPatches = [ ./rustc-serialize-fix.patch ];

  cargoHash = "sha256-unx2XGi16aWvw5dceAuReMEMLGcO/JwYpx9Ewvrw3KE=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    libgit2
    openssl
    curl
  ];

  preCheck = lib.optionalString stdenv.hostPlatform.isDarwin ''
    # Darwin issue: Os { code: 24, kind: Uncategorized, message: "Too many open files" }
    # https://github.com/google/cargo-raze/issues/544
    ulimit -n 1024
  '';

  __darwinAllowLocalNetworking = true;

  meta = {
    description = "Generate Bazel BUILD files from Cargo dependencies";
    homepage = "https://github.com/google/cargo-raze";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ elasticdog ];
  };
}
