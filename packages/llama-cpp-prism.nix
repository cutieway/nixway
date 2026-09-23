{
  stdenvNoCC,
  fetchzip,
  autoPatchelfHook,
  openssl,
  gcc,
  rocmPackages,
}:

# PrismML's binary fork of llama.cpp with ternary kernels. Kept out of the
# Home Manager module so `update-ai` can bump it with `nix-update` like the
# other locally packaged AI tools.
#
# Upstream tags releases as `prism-<build>-<rev>` and names the ROCm asset
# with the tag prefix stripped, so `version` stores only `<build>-<rev>` and
# the URL adds the prefix back. nix-update extracts the same suffix with
# `--version-regex 'prism-(.*)'`.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "llama-cpp-prism";
  version = "b10709-9a9394a";

  src = fetchzip {
    url = "https://github.com/PrismML-Eng/llama.cpp/releases/download/prism-${finalAttrs.version}/llama-prism-${finalAttrs.version}-bin-ubuntu-rocm-7.2-x64.tar.gz";
    hash = "sha256-Ht+IB+12JAc8u9qNAfifK/8gTtzfYn+AQH1U8z4ZRew=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    openssl
    gcc.cc.lib
    rocmPackages.clr
    rocmPackages.hipblas
    rocmPackages.rocblas
  ];

  installPhase = ''
    mkdir -p $out/bin
    for f in llama-* ggml-rpc-server; do
      test -f "$f" -a -x "$f" && cp -a "$f" $out/bin/
    done
    for f in lib*.so*; do
      test -f "$f" && cp -a "$f" $out/bin/
    done
  '';

  meta = {
    description = "PrismML fork of llama.cpp with ternary kernel support (ROCm)";
    homepage = "https://github.com/PrismML-Eng/llama.cpp";
    platforms = [ "x86_64-linux" ];
    mainProgram = "llama-server";
  };
})
