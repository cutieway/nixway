{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  fetchzip,
  python3,
  nodejs,
}:

# Self-contained package: not an override of the llm-agents derivation.
# We copy the structure of the llm-agents claude-code-router expression
# but pin a newer version (3.0.7) that fixes stream-disconnect and
# OpenCode-Zen-400 crashes.  See:
#   https://github.com/musistudio/claude-code-router

let
  version = "3.0.7";
in

buildNpmPackage (finalAttrs: {
  pname = "claude-code-router";
  inherit version;

  # The GitHub repo carries package-lock.json (needed for npmDepsHash) but
  # not the built dist/ tree; the npm registry tarball is the other way
  # round. We install runtime dependencies from the former and drop the
  # prebuilt bundle from the latter on top, avoiding the fragile
  # Electron/React devDependency set required to rebuild dist/ from source.
  src = fetchFromGitHub {
    owner = "musistudio";
    repo = "claude-code-router";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DNPQh39eIPEtvwBXUolH9TPe6LA+ES+U57WoK3TEHgc=";
  };

  dist = fetchzip {
    url = "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-${finalAttrs.version}.tgz";
    hash = "sha256-oMPA9sAt4T87b+tobnnSEMch1xDhNg/J43Jwhki/42k=";
  };

  npmDepsHash = "sha256-vh3bvF12WAZ6be9W+wsnZl4laZOmewEHEiiLL0YvNUo=";

  dontNpmBuild = true;

  # Only production dependencies are needed at runtime; devDependencies
  # pull in Electron/React with unresolved peer deps upstream.
  npmFlags = [
    "--omit=dev"
    "--legacy-peer-deps"
  ];
  makeCacheWritable = true;

  nativeBuildInputs = [
    python3 # better-sqlite3 node-gyp rebuild
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib # better-sqlite3 native addon
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    # better-sqlite3 ships prebuild-install prebuilds; force a source build
    # so the resulting .node targets nixpkgs' node ABI and libc.
    npm_config_build_from_source = "true";
  };

  # npm pack (used by npmInstallHook) only ships paths listed in
  # package.json#files, so the prebuilt bundle has to be in place first.
  preInstall = ''
    cp -r ${finalAttrs.dist}/dist dist
    chmod -R u+w dist
  '';

  postInstall = ''
    # Drop node-gyp intermediate objects that leak /build/ references.
    rm -rf $out/lib/node_modules/claude-code-router/node_modules/better-sqlite3/build/Release/obj.target
  '';

  # Upstream's 3.x CLI has no --version/-v flag and every subcommand aborts
  # early without a configured provider, so we treat that guarded exit as a
  # smoke test: reaching it means node, better-sqlite3 and the bundled
  # dist/ all loaded correctly.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    # ccr exits non-zero on the guard message; capture instead of piping
    # so stdenv's pipefail does not fail the phase before grep runs.
    output=$(HOME=$TMPDIR $out/bin/ccr help 2>&1 || true)
    grep -q "Configure at least one provider" <<<"$output"
    runHook postInstallCheck
  '';

  passthru = {
    inherit (finalAttrs) dist;
    category = "Claude Code Ecosystem";
  };

  meta = with lib; {
    description = "Use Claude Code without an Anthropics account and route it to another LLM provider";
    homepage = "https://github.com/musistudio/claude-code-router";
    changelog = "https://github.com/musistudio/claude-code-router/releases/tag/v${finalAttrs.version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryBytecode # bundled dist/ from npm registry
    ];
    maintainers = with maintainers; [ ];
    mainProgram = "ccr";
    inherit (nodejs.meta) platforms;
  };
})
