{ pkgs, ... }:

let
  llamaCpp = pkgs.llama-cpp-rocm;

  llm = pkgs.writeShellApplication {
    name = "llm";
    runtimeInputs = [ llamaCpp pkgs.coreutils pkgs.findutils ];
    text = ''
      models_dir="''${LLM_MODELS_DIR:-/home/lexi/.lmstudio/models}"

      pick_model() {
        dir="$1"
        # prefer the largest non-mmproj .gguf
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

      # resolve model path
      case "$query" in
        /*) model_path="$(pick_model "$query")" ;;
        */*)
          # provider/model
          dir="$models_dir/$query"
          if [ -d "$dir" ]; then
            model_path="$(pick_model "$dir")"
          fi
          ;;
        *)
          # bare name — search all providers
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

      exec llama-server \
        --model "$model_path" \
        --ctx-size "''${LLAMA_CONTEXT:-16384}" \
        --parallel 1 \
        --flash-attn auto \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        -ngl "''${LLAMA_NGL:-0}" \
        --host "''${LLAMA_HOST:-127.0.0.1}" \
        --port "''${LLAMA_PORT:-8080}" \
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
