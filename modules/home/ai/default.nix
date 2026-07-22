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
    runtimeInputs = [ llamaCpp llamaCppPrism pkgs.coreutils pkgs.findutils ];
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

      flatten_config() {
        local line
        while IFS= read -r line || [ -n "$line" ]; do
          if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
          fi
          while [[ "$line" == *[[:space:]] ]]; do
            line="''${line%?}"
          done
          if [[ "$line" == *\\ ]]; then
            line="''${line%\\}"
          fi
          printf '%s ' "$line"
        done
      }

      default_config() {
        local model_q
        printf -v model_q '%q' "$model_path"
        cat <<EOF
llama-server \\
  # -----------------------------------------------------------------
  # 1. MODEL & IDENTITY
  # -----------------------------------------------------------------
  -m $model_q \\
  --alias ''${LLM_MODEL_ALIAS:-local} \\
  --jinja \\
  # -----------------------------------------------------------------
  # 2. HARDWARE ACCELERATION & GPU OFFLOAD
  # -----------------------------------------------------------------
  -ngl auto \\
  --flash-attn auto \\
  --threads -1 \\
  --mmap \\
  --fit-target ''${LLM_FIT_TARGET:-2048} \\
  --n-cpu-moe 0 \\
  # -----------------------------------------------------------------
  # 3. CONTEXT, BATCHING & KV CACHE
  # -----------------------------------------------------------------
  --ctx-size ''${LLM_CTX_SIZE:-65536} \\
  --batch-size 2048 \\
  --ubatch-size 1024 \\
  --cache-type-k ''${LLM_CACHE_TYPE_K:-q8_0} \\
  --cache-type-v ''${LLM_CACHE_TYPE_V:-q8_0} \\
  --cache-reuse 256 \\
  # -----------------------------------------------------------------
  # 4. SERVER, NETWORKING & CONCURRENCY
  # -----------------------------------------------------------------
  --host 127.0.0.1 \\
  --port 8080 \\
  --parallel 1 \\
  # -----------------------------------------------------------------
  # 5. SAMPLING & GENERATION DEFAULTS
  # -----------------------------------------------------------------
  --temp 0.7 \\
  --top-k 20 \\
  --top-p 0.95 \\
  --min-p 0.00 \\
  --presence-penalty 0.0 \\
  --repeat-penalty 1.0
EOF
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
        echo "  Each launch prints the complete grouped config and waits for Enter."
        echo "  Edit the sidecar with any text editor; command-line options are temporary."
        echo ""
        echo "Environment variables:"
        echo "  LLM_MODELS_DIR    model storage root (default: ~/.lmstudio/models)"
        echo "  LLM_MODEL_ALIAS   model ID used when creating a config (default: local)"
        echo "  LLM_CTX_SIZE      context used when creating a config (default: 65536)"
        echo "  LLM_CACHE_TYPE_K  key cache used when creating a config (default: q8_0)"
        echo "  LLM_CACHE_TYPE_V  value cache used when creating a config (default: q8_0)"
        echo "  LLM_FIT_TARGET    VRAM reserve used when creating a config (default: 2048)"
        echo "  LLM_BACKEND       backend: auto, standard, or prism (default: auto)"
        echo "  LLM_NO_CONFIRM    set to 1 to launch without printing or prompting"
        echo ""
        echo "Common llama-server flags (pass any after model):"
        echo "  -ngl VALUE              GPU layers: auto, all, or an exact number"
        echo "  --ctx-size N            context window in tokens"
        echo "  --n-cpu-moe N           keep MoE weights of first N layers in CPU/RAM"
        echo "  -t N, --threads N       CPU generation threads"
        echo "  --no-mmap               load model fully into RAM"
        echo "  --mlock                 lock model in RAM (prevents swapping)"
        echo "  --temp N                temperature (default 0.7)"
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

      config_text="$(< "$config_path")"
      if [ -z "''${config_text//[[:space:]]/}" ]; then
        default_config > "$config_path"
        config_text="$(< "$config_path")"
        echo "Initialized empty config: $config_path" >&2
      fi

      launch_args="$(flatten_config <<< "$config_text")"

      if ! printf '%s\n' "$launch_args" | xargs --no-run-if-empty true; then
        echo "Error: invalid quoting in launch arguments" >&2
        exit 2
      fi

      config_args=()
      if [ -n "$launch_args" ]; then
        mapfile -d "" -t config_args < <(
          printf '%s\n' "$launch_args" |
            xargs --no-run-if-empty printf '%s\0'
        )
      fi

      display_config="$config_text"
      if [ "''${#config_args[@]}" -gt 0 ] && [ "''${config_args[0]}" = llama-server ]; then
        server_args=("''${config_args[@]:1}")
      else
        printf -v model_q '%q' "$model_path"
        display_config="llama-server \\"$'\n'"  -m $model_q \\"$'\n'"$config_text"
        server_args=(-m "$model_path" "''${config_args[@]}")
        echo "Note: showing the existing arguments-only config as a complete command." >&2
        echo "Delete it once to generate the new grouped format." >&2
      fi
      server_args+=("$@")

      no_confirm="''${LLM_NO_CONFIRM:-''${LLM_NO_EDIT:-0}}"
      if [ -t 0 ] && [ -t 1 ] && [ "$no_confirm" != 1 ]; then
        printf '%s\n\n' "$display_config"
        if [ $# -gt 0 ]; then
          printf 'Temporary arguments:'
          printf ' %q' "$@"
          printf '\n\n'
        fi
        if ! IFS= read -r -p "Press Enter to launch (Ctrl+C to cancel) "; then
          printf '\n' >&2
          exit 130
        fi
      fi

      echo "Model:   $model_path" >&2
      echo "Backend: $server" >&2
      exec "$server" "''${server_args[@]}"
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
