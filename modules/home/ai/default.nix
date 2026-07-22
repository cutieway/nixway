{ pkgs, ... }:

let
  llamaCpp = pkgs.llama-cpp-rocm;

  backendLoader = pkgs.stdenv.mkDerivation {
    pname = "llama-backend-loader";
    version = "1";
    dontUnpack = true;
    buildInputs = [ pkgs.glibc ];
    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/llama-backend-loader.c << 'EOF'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <program> [args...]\n", argv[0]);
        return 1;
    }

    const char *lib_dir = getenv("LLAMA_BACKEND_LIB_DIR");
    if (!lib_dir) {
        fprintf(stderr, "LLAMA_BACKEND_LIB_DIR not set\n");
        return 1;
    }

    // Build paths and load each backend
    const char *backends[] = {"libggml-cpu-x64.so", "libggml-hip.so", NULL};
    for (int i = 0; backends[i]; i++) {
        char path[4096];
        snprintf(path, sizeof(path), "%s/%s", lib_dir, backends[i]);

        void *handle = dlopen(path, RTLD_NOW | RTLD_GLOBAL);
        if (!handle) {
            fprintf(stderr, "Warning: failed to dlopen %s: %s\n", path, dlerror());
            continue;
        }

        // Call ggml_backend_init to register the backend
        void (*init)(void) = dlsym(handle, "ggml_backend_init");
        if (init) {
            init();
        }
    }

    execvp(argv[1], argv + 1);
    perror("execvp");
    return 1;
}
EOF
      $CC -O2 -o $out/bin/backend-loader $out/bin/llama-backend-loader.c -ldl
      rm $out/bin/llama-backend-loader.c
    '';
  };

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
    '';

    meta = {
      description = "PrismML fork of llama.cpp with ternary kernel support (ROCm)";
      platforms = [ "x86_64-linux" ];
    };
  };

  prismWithLoader = pkgs.stdenvNoCC.mkDerivation {
    name = "llama-cpp-prism-loaded";
    buildInputs = [ pkgs.makeWrapper ];
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/bin $out/libexec

      # Symlink the backend loader
      ln -s ${backendLoader}/bin/backend-loader $out/bin/

      # Wrapper scripts that load both backends then exec the real binary
      for bin in ${llamaCppPrism}/libexec/llama-cpp-prism/*; do
        name=$(basename "$bin")
        [ -x "$bin" ] || continue
        [ -L "$bin" ] && continue

        cat > "$out/bin/$name" << WRAP
#! ${pkgs.bash}/bin/bash
LLAMA_BACKEND_LIB_DIR=${llamaCppPrism}/lib \
LD_LIBRARY_PATH=${llamaCppPrism}/lib:${pkgs.rocmPackages.clr}/lib \
  ${backendLoader}/bin/backend-loader "$bin" "\$@"
WRAP
        chmod +x "$out/bin/$name"
        ln -s "$bin" "$out/libexec/$name"
      done
    '';
  };

  llm = pkgs.writeShellApplication {
    name = "llm";
    runtimeInputs = [ llamaCpp prismWithLoader pkgs.coreutils pkgs.findutils ];
    text = ''
      models_dir="''${LLM_MODELS_DIR:-$HOME/.lmstudio/models}"

      pick_model() {
        dir="$1"
        found=""
        while IFS= read -r candidate; do
          filename="$(basename "$candidate")"
          case "$filename" in
            *-[0-9][0-9][0-9][0-9][0-9]-of-[0-9][0-9][0-9][0-9][0-9].gguf)
              shard_prefix="''${filename%-of-*}"
              shard_num="''${shard_prefix##*-}"
              [ "$shard_num" != "00001" ] && continue
              ;;
          esac
          found="$candidate"
          break
        done <<EOF
$(find "$dir" -maxdepth 1 -type f \
  -name '*.gguf' \
  ! -name 'mmproj-*' \
  -printf '%s %p\n' |
  sort -rn |
  cut -d' ' -f2-)
EOF
        printf '%s\n' "$found"
      }

      list_models() {
        if [ ! -d "$models_dir" ]; then
          echo "  (directory $models_dir not found)" >&2
          return
        fi
        find "$models_dir" -mindepth 2 -maxdepth 2 -type d | sort | while read -r dir; do
          provider=$(basename "$(dirname "$dir")")
          name=$(basename "$dir")
          if [ -n "$(pick_model "$dir")" ]; then
            printf "  %-30s %s\n" "$provider/$name" ""
          fi
        done
      }

      usage() {
        echo "Usage: llm <model> [options...]"
        echo "       llm (list|--help)"
        echo ""
        echo "Model resolution:"
        echo "  llm HauhauCS/Qwen3.5-9B  - provider/model name"
        echo "  llm Qwen3.5-9B           - searches all providers"
        echo "  llm /path/to/model.gguf  - absolute path"
        echo ""
        echo "Environment variables:"
        echo "  LLM_MODELS_DIR    model storage root (default: ~/.lmstudio/models)"
        echo "  LLM_MODEL_ALIAS   model ID exposed by llama-server (default: local)"
        echo "  LLM_CTX_SIZE      context window (default: 65536)"
        echo "  LLM_CACHE_TYPE_K  key cache type (default: q8_0)"
        echo "  LLM_CACHE_TYPE_V  value cache type (default: q8_0)"
        echo "  LLM_BACKEND       backend: auto, standard, or prism (default: auto)"
        echo ""
        echo "Common llama-server flags (pass any after model):"
        echo "  -ngl VALUE              GPU layers: auto, all, or an exact number"
        echo "  --ctx-size N            context window in tokens"
        echo "  --n-cpu-moe N           keep MoE weights of first N layers in CPU/RAM"
        echo "  -t N, --threads N       CPU generation threads"
        echo "  --no-mmap               load model fully into RAM"
        echo "  --mlock                 lock model in RAM (prevents swapping)"
        echo "  --temp N                temperature (default 0.8)"
        echo "  --seed N                random seed (-1 = random)"
        echo "  --host ADDR             bind address (default 127.0.0.1)"
        echo "  --port N                port (default 8080)"
        echo ""
        echo "Note: -ngl is shorthand for --n-gpu-layers. llama.cpp uses"
        echo "single-dash abbreviations (-ngl) alongside long flags (--ctx-size)"
        echo "for historical reasons. Both forms work."
      }

      if [ $# -eq 0 ]; then
        list_models
        exit 0
      fi

      if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
        usage
        exit 0
      fi

      if [ "$1" = "list" ]; then
        list_models
        exit 0
      fi

      query="$1"
      shift

      model_path=""

      case "$query" in
        /*)
          if [ -f "$query" ]; then
            model_path="$query"
          elif [ -d "$query" ]; then
            model_path="$(pick_model "$query")"
          fi
          ;;
        */*)
          dir="$models_dir/$query"
          if [ -d "$dir" ]; then
            model_path="$(pick_model "$dir")"
          fi
          ;;
        *)
          while IFS= read -r dir; do
            candidate="$(pick_model "$dir")"
            if [ -n "$candidate" ]; then
              if [ -z "$model_path" ]; then
                model_path="$candidate"
              else
                echo "Error: multiple providers match '$query':" >&2
                while IFS= read -r d; do
                  if [ -n "$(pick_model "$d")" ]; then
                    printf '  %s/%s\n' "$(basename "$(dirname "$d")")" "$(basename "$d")" >&2
                  fi
                done < <(find "$models_dir" -mindepth 2 -maxdepth 2 -type d -name "$query" 2>/dev/null | sort)
                echo "Use provider/model syntax to disambiguate." >&2
                exit 1
              fi
            fi
          done < <(find "$models_dir" -mindepth 2 -maxdepth 2 -type d -name "$query" 2>/dev/null)
          ;;
      esac

      if [ -z "$model_path" ] || [ ! -f "$model_path" ]; then
        echo "Model not found: $query" >&2
        echo "Use 'llm list' to see available models." >&2
        exit 1
      fi

      case "''${LLM_BACKEND:-auto}" in
        prism)
          server="${prismWithLoader}/bin/llama-server"
          ;;
        auto)
          case "$model_path" in
            */prism-ml/*) server="${prismWithLoader}/bin/llama-server" ;;
            *)            server="${llamaCpp}/bin/llama-server" ;;
          esac
          ;;
        *)
          echo "Invalid LLM_BACKEND: $LLM_BACKEND" >&2
          echo "Expected: auto, standard, or prism" >&2
          exit 2
          ;;
      esac

      echo "Model:   $model_path" >&2
      echo "Backend: $server" >&2
      echo "Context: ''${LLM_CTX_SIZE:-65536}" >&2

      exec "$server" \
        --model "$model_path" \
        --alias "''${LLM_MODEL_ALIAS:-local}" \
        --ctx-size "''${LLM_CTX_SIZE:-65536}" \
        -ngl auto \
        --parallel 1 \
        --flash-attn auto \
        --cache-type-k "''${LLM_CACHE_TYPE_K:-q8_0}" \
        --cache-type-v "''${LLM_CACHE_TYPE_V:-q8_0}" \
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
