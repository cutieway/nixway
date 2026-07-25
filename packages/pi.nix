{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchurl,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  ripgrep,
  fd,
  makeBinaryWrapper,
  stdenvNoCC,
}:
buildNpmPackage (finalAttrs: {
  pname = "pi-coding-agent";
  version = "0.82.1";

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${finalAttrs.version}";
    hash = "sha256-LESpgd/KUoNqdBfnd1oyMN8coKm0Odbo9GYkUDry8Zk=";
  };

  npmDepsHash = "sha256-5pHRwxpKg95/phOcYHeWdvPJNtSOhiw7PRoVxsuh0RM=";

  npmWorkspace = "packages/coding-agent";

  npmRebuildFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    makeBinaryWrapper
  ];

  # Pre-generated model data from the npm-registry dist tarball (the git
  # source no longer commits these files — they are produced by a generate-
  # models script that requires network access at build time).
  modelData = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${finalAttrs.version}.tgz";
    hash = "sha256-L535UigItiHNNEmHZTfwPYqN+LjX7C1bGMapEKqFtJA=";
  };

  preBuild = ''
    tar xzf ${finalAttrs.modelData} -C /tmp
    cp -r /tmp/package/dist/providers/data packages/ai/src/providers/data
    chmod -R u+w packages/ai/src/providers/data
  '';

  buildPhase = ''
    runHook preBuild

    npx tsgo -p packages/ai/tsconfig.build.json
    npx tsgo -p packages/tui/tsconfig.build.json
    npx tsgo -p packages/agent/tsconfig.build.json
    npm run build --workspace=packages/coding-agent

    runHook postBuild
  '';

  postInstall = ''
    local nm="$out/lib/node_modules/pi-monorepo/node_modules"

    for ws in @earendil-works/pi-ai:packages/ai \
              @earendil-works/pi-agent-core:packages/agent \
              @earendil-works/pi-tui:packages/tui; do
      IFS=: read -r pkg src <<< "$ws"
      rm "$nm/$pkg"
      cp -r "$src" "$nm/$pkg"
    done

    find "$nm" -type l -lname '*/packages/*' -delete
    find "$nm/.bin" -xtype l -delete
  ''
  + lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
    find "$nm/koffi/build/koffi" -mindepth 1 -maxdepth 1 -type d \
      ! -name 'darwin_*' -exec rm -r {} +
    rm -rf \
      "$nm/@anthropic-ai/sandbox-runtime/dist/vendor/seccomp" \
      "$nm/@anthropic-ai/sandbox-runtime/vendor/seccomp"
  '';

  postFixup = "wrapProgram $out/bin/pi --prefix PATH : ${
    lib.makeBinPath [
      ripgrep
      fd
    ]
  }";

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgram = "${placeholder "out"}/bin/pi";
  versionCheckProgramArg = "--version";

  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://pi.dev/";
    downloadPage = "https://www.npmjs.com/package/@earendil-works/pi-coding-agent";
    changelog = "https://github.com/earendil-works/pi/blob/main/packages/coding-agent/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "pi";
  };
})
