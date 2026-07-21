{ pkgs, ... }:

let
  llamaCpp = pkgs.llama-cpp-rocm;

  llamaCppPrism = pkgs.stdenvNoCC.mkDerivation {
    pname = "llama-cpp-prism";
    version = "prism-b9596-9fcaed7";

    src = pkgs.fetchzip {
      url = "https://github.com/PrismML-Eng/llama.cpp/releases/download/prism-b9596-9fcaed7/llama-prism-b9596-9fcaed7-bin-ubuntu-rocm-7.2-x64.tar.gz";
      hash = "sha256-UJA2c4QF9Xlqnr292h3gOnzXJJRPr7K0cuPQUB4tsfU=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
    buildInputs = with pkgs; [
      openssl
      gcc.cc.lib
      rocmPackages.clr
      rocmPackages.hipblas
      rocmPackages.rocblas
    ];

    installPhase = ''
      mkdir -p $out/lib $out/libexec/llama-cpp-prism
      for f in llama-* rpc-server; do
        test -f "$f" -a -x "$f" && cp -a "$f" $out/libexec/llama-cpp-prism/
      done
      for f in lib*.so*; do
        test -f "$f" && cp -a "$f" $out/lib/
      done

      backend="$out/lib/libggml-hip.so"
      for f in $out/libexec/llama-cpp-prism/*; do
        if [ -x "$f" ] && [ ! -L "$f" ]; then
          wrapProgram "$f" --set GGML_BACKEND_PATH "$backend"
        fi
      done
    '';

    meta = {
      description = "PrismML fork of llama.cpp with ternary kernel support (ROCm)";
      platforms = [ "x86_64-linux" ];
    };
  };

  llm = pkgs.writeShellApplication {
    name = "llm";
    runtimeInputs = [ llamaCpp llamaCppPrism pkgs.coreutils pkgs.findutils ];
    text = ''
      models_dir="''${LLM_MODELS_DIR:-/home/lexi/.lmstudio/models}"

      pick_model() {
        dir="$1"
        found=$(find "$dir" -maxdepth 1 -name '*.gguf' ! -name 'mmproj-*' -printf '%s %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
        if [ -z "$found" ]; then
          found=$(find "$dir" -maxdepth 1 -name '*.gguf' -printf '%s %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
        fi
        echo "$found"
      }

      list_models() {
        find "$models_dir" -mindepth 2 -maxdepth 2 -type d | sort | while read -r dir; do
          provider=$(basename "$(dirname "$dir")")
          name=$(basename "$dir")
          if [ -n "$(pick_model "$dir")" ]; then
            printf "  %-30s %s\n" "$provider/$name" ""
          fi
        done
      }

      if [ $# -eq 0 ]; then
        echo "Usage: llm <model> [llama-server args...]"
        echo "       llm list"
        echo ""
        echo "Available models:"
        if [ -d "$models_dir" ]; then
          list_models
        else
          echo "  (directory $models_dir not found)"
        fi
        exit 1
      fi

      if [ "$1" = "list" ]; then
        list_models
        exit 0
      fi

      query="$1"
      shift

      case "$query" in
        /*) model_path="$(pick_model "$query")" ;;
        */*)
          dir="$models_dir/$query"
          if [ -d "$dir" ]; then
            model_path="$(pick_model "$dir")"
          fi
          ;;
        *)
          dir=$(find "$models_dir" -mindepth 2 -maxdepth 2 -type d -name "$query" | head -1)
          if [ -n "$dir" ]; then
            model_path="$(pick_model "$dir")"
          fi
          ;;
      esac

      if [ -z "$model_path" ] || [ ! -f "$model_path" ]; then
        echo "Model not found: $query" >&2
        echo "Use 'llm list' to see available models." >&2
        exit 1
      fi

      # use PrismML fork for prism-ml models, standard llama-cpp for everything else
      case "$model_path" in
        */prism-ml/*) server="${llamaCppPrism}/libexec/llama-cpp-prism/llama-server" ;;
        *)            server="${llamaCpp}/bin/llama-server" ;;
      esac

      exec "$server" \
        --model "$model_path" \
        --parallel 1 \
        --flash-attn auto \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        "$@"
    '';
  };

in
{
  home.packages = [
    llamaCpp
    pkgs.amdgpu_top
    llm
  ];

  programs.bash.shellAliases = {
    ai-devices = "llama-server --list-devices";
    ai-gpu = "amdgpu_top";
  };
}
