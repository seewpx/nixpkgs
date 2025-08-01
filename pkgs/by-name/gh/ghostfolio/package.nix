{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  faketty,
  openssl,
  prisma,
  prisma-engines,
}:

buildNpmPackage rec {
  pname = "ghostfolio";
  version = "2.185.0";

  src = fetchFromGitHub {
    owner = "ghostfolio";
    repo = "ghostfolio";
    tag = version;
    hash = "sha256-jnC2u9ZZcOSux6UUzW9Ot02aFWeGYhrdCC9d4xM0efA=";
    # populate values that require us to use git. By doing this in postFetch we
    # can delete .git afterwards and maintain better reproducibility of the src.
    leaveDotGit = true;
    postFetch = ''
      date -u -d "@$(git -C $out log -1 --pretty=%ct)" +%s%3N > $out/SOURCE_DATE_EPOCH
      find "$out" -name .git -print0 | xargs -0 rm -rf
    '';
  };

  npmDepsHash = "sha256-FCH0v9jRviH33mfIVX8967X1u494qToHraYVn5pbSPw=";

  nativeBuildInputs = [
    prisma
    faketty
  ];

  # Disallow cypress from downloading binaries in sandbox
  env.CYPRESS_INSTALL_BINARY = "0";

  buildPhase = ''
    runHook preBuild

    prisma generate

    substituteInPlace replace.build.mjs \
      --replace-fail 'new Date()' "new Date(''$(<SOURCE_DATE_EPOCH))"

    # Workaround for https://github.com/nrwl/nx/issues/22445
    faketty npm run build:production

    cp -r node_modules dist/apps/api/
    cp -r prisma dist/apps/api/

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/node_modules/ghostfolio"
    cp -r dist/apps/{api,client} "$out/lib/node_modules/ghostfolio/"

    mkdir "$out/bin"
    makeWrapper ${lib.getExe nodejs} "$out/bin/ghostfolio" \
      --add-flags "$out/lib/node_modules/ghostfolio/api/main" "''${user_args[@]}" \
      --prefix PATH : ${lib.makeBinPath [ openssl ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ openssl ]} \
      ${lib.concatStringsSep " " (
        lib.mapAttrsToList (name: value: "--set ${name} ${lib.escapeShellArg value}") {
          PRISMA_SCHEMA_ENGINE_BINARY = lib.getExe' prisma-engines "schema-engine";
          PRISMA_QUERY_ENGINE_BINARY = lib.getExe' prisma-engines "query-engine";
          PRISMA_QUERY_ENGINE_LIBRARY = "${prisma-engines}/lib/libquery_engine.node";
          PRISMA_INTROSPECTION_ENGINE_BINARY = lib.getExe' prisma-engines "introspection-engine";
          PRISMA_FMT_BINARY = lib.getExe' prisma-engines "prisma-fmt";
        }
      )}

    runHook postInstall
  '';

  meta = {
    description = "Open Source Wealth Management Software";
    homepage = "https://github.com/ghostfolio/ghostfolio";
    changelog = "https://github.com/ghostfolio/ghostfolio/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ moraxyc ];
    mainProgram = "ghostfolio";
  };
}
