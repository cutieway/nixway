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

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [
      openssl
      gcc.cc.lib
      rocmPackages.clr
      rocmPackages.hipblas
      rocmPackages.rocblas
    ];

    installPhase = ''
      mkdir -p $out/bin
      for f in llama-* rpc-server; do
        test -f "$f" -a -x "$f" && cp -a "$f" $out/bin/
      done
      for f in lib*.so*; do
        test -f "$f" && cp -a "$f" $out/bin/
      done
    '';

    meta = {
      description = "PrismML fork of llama.cpp with ternary kernel support (ROCm)";
      platforms = [ "x86_64-linux" ];
    };
  };

  llm = pkgs.writeShellApplication {
    name = "llm";
    runtimeInputs = [ llamaCpp llamaCppPrism pkgs.coreutils pkgs.findutils pkgs.gum ];
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

      default_config() {
        local args=(
          --alias "''${LLM_MODEL_ALIAS:-local}"
          --ctx-size "''${LLM_CTX_SIZE:-65536}"
          --batch-size 2048
          --ubatch-size 512
          --threads -1
          -ngl auto
          --fit-target "''${LLM_FIT_TARGET:-2048}"
          --n-cpu-moe 0
          --parallel 1
          --flash-attn auto
          --kv-offload
          --kv-unified
          --cache-type-k "''${LLM_CACHE_TYPE_K:-q8_0}"
          --cache-type-v "''${LLM_CACHE_TYPE_V:-q8_0}"
          --mmap
          --jinja
          --cache-prompt
          --cache-reuse 0
          --spec-type none
          --temp 0.8
          --top-k 40
          --top-p 0.95
          --min-p 0.05
          --presence-penalty 0.0
          --repeat-penalty 1.0
          --host 127.0.0.1
          --port 8080
        )
        printf '%q ' "''${args[@]}"
        printf '\n'
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
        echo "Launch configuration:"
        echo "  The first launch creates <model>.gguf.llm.conf beside the GGUF."
        echo "  Interactive launches present its arguments as an editable command."
        echo "  Press Enter to save and launch; extra CLI options are appended first."
        echo ""
        echo "Environment variables:"
        echo "  LLM_MODELS_DIR    model storage root (default: ~/.lmstudio/models)"
        echo "  LLM_MODEL_ALIAS   model ID used when creating a config (default: local)"
        echo "  LLM_CTX_SIZE      context used when creating a config (default: 65536)"
        echo "  LLM_CACHE_TYPE_K  key cache used when creating a config (default: q8_0)"
        echo "  LLM_CACHE_TYPE_V  value cache used when creating a config (default: q8_0)"
        echo "  LLM_FIT_TARGET    VRAM reserve used when creating a config (default: 2048)"
        echo "  LLM_BACKEND       backend: auto, standard, or prism (default: auto)"
        echo "  LLM_NO_EDIT       set to 1 to launch the saved config without prompting"
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
          server="${llamaCppPrism}/bin/llama-server"
          ;;
        standard)
          server="${llamaCpp}/bin/llama-server"
          ;;
        auto)
          case "$model_path" in
            */prism-ml/*) server="${llamaCppPrism}/bin/llama-server" ;;
            *)            server="${llamaCpp}/bin/llama-server" ;;
          esac
          ;;
        *)
          echo "Invalid LLM_BACKEND: $LLM_BACKEND" >&2
          echo "Expected: auto, standard, or prism" >&2
          exit 2
          ;;
      esac

      config_path="$model_path.llm.conf"
      if [ ! -e "$config_path" ]; then
        default_config > "$config_path"
        echo "Created config: $config_path" >&2
      elif [ ! -f "$config_path" ]; then
        echo "Error: model config is not a regular file: $config_path" >&2
        exit 2
      fi

      saved_args="$(tr '\n' ' ' < "$config_path")"
      if [ -z "''${saved_args//[[:space:]]/}" ]; then
        default_config > "$config_path"
        saved_args="$(tr '\n' ' ' < "$config_path")"
        echo "Initialized empty config: $config_path" >&2
      fi

      extra_args=""
      if [ $# -gt 0 ]; then
        printf -v extra_args ' %q' "$@"
      fi
      launch_args="$saved_args$extra_args"

      interactive=0
      if [ -t 0 ] && [ -t 1 ] && [ "''${LLM_NO_EDIT:-0}" != 1 ]; then
        interactive=1
        printf -v quoted_model '%q' "$model_path"
        if ! edited_args="$(
          gum input \
            --header="llama-server --model $quoted_model" \
            --prompt="arguments> " \
            --value="$launch_args" \
            --char-limit 0 \
            --width 0 \
            --show-help
        )"; then
          printf '\n' >&2
          exit 130
        fi
        if [ -z "''${edited_args//[[:space:]]/}" ]; then
          echo "Empty edit ignored; keeping the saved launch arguments." >&2
          edited_args="$launch_args"
        fi
        launch_args="$edited_args"
      fi

      if ! printf '%s\n' "$launch_args" | xargs --no-run-if-empty true; then
        echo "Error: invalid quoting in launch arguments" >&2
        exit 2
      fi

      model_args=()
      if [ -n "$launch_args" ]; then
        mapfile -d "" -t model_args < <(
          printf '%s\n' "$launch_args" |
            xargs --no-run-if-empty printf '%s\0'
        )
      fi

      if [ "$interactive" -eq 1 ]; then
        printf '%s\n' "$launch_args" > "$config_path"
        echo "Saved config: $config_path" >&2
      fi

      echo "Model:   $model_path" >&2
      echo "Backend: $server" >&2
      exec "$server" --model "$model_path" "''${model_args[@]}"
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
