{ pkgs, ... }:

let
  llamaCpp = pkgs.llama-cpp-rocm;

  llm = pkgs.writeShellApplication {
    name = "llm";
    runtimeInputs = [ llamaCpp ];
    text = ''
      models_dir="''${LLM_MODELS_DIR:-/home/lexi/.lmstudio/models}"

      if [ $# -eq 0 ]; then
        echo "Usage: llm <model.gguf> [llama-server args...]"
        echo ""
        echo "Available models:"
        if ls -1 "$models_dir"/*.gguf >/dev/null 2>&1; then
          ls -1 "$models_dir"/*.gguf
        else
          echo "  (no .gguf files in $models_dir)"
        fi
        exit 1
      fi

      model="$1"
      shift

      case "$model" in
        /*) model_path="$model" ;;
        *)  model_path="$models_dir/$model" ;;
      esac

      if [ ! -f "$model_path" ]; then
        echo "Model not found: $model_path" >&2
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
