{
  lib,
  buildNpmPackage,
  fetchurl,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

# OpenChamber is an Agentic Development Environment built on the OpenCode
# agent: a desktop/web/VS Code/mobile/CLI workspace that drives `opencode`
# rather than talking to model providers itself.
#
# The published @openchamber/web tarball is prebuilt — dist/, server/ and
# public/ ship ready to run — so nothing is compiled here. Upstream builds
# with bun, so the tarball carries no package-lock.json; a lock generated from
# the published package.json is vendored beside this file and handed to npm in
# postPatch (the documented buildNpmPackage escape hatch).
buildNpmPackage (finalAttrs: {
  pname = "openchamber";
  version = "1.24.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/@openchamber/web/-/web-${finalAttrs.version}.tgz";
    hash = "sha256-mrefb1ENRZj3ZNlCCKRCAqUFFVW58l/6K+YSLqeJ6zQ=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-RK8/6PBp3dh1dHdSCWwTNqd6tODBnTLRqrkT4U4j9LI=";

  # dist/ + server/ + public/ are already built in the published tarball.
  dontNpmBuild = true;

  # Runtime dependencies only; the tarball's package.json still lists the
  # frontend devDependencies used to produce dist/. node-pty and sherpa-onnx
  # ship prebuilt bindings, so their install scripts are never run. The
  # package's `prepack` wants bun to rebuild extensions, which is unnecessary
  # for an already-published tarball.
  npmFlags = [ "--omit=dev" ];
  npmPackFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgram = "${placeholder "out"}/bin/openchamber";
  versionCheckProgramArg = "--version";

  meta = {
    description = "Agentic Development Environment based on the OpenCode AI agent";
    homepage = "https://github.com/openchamber/openchamber";
    changelog = "https://github.com/openchamber/openchamber/blob/main/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "openchamber";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
