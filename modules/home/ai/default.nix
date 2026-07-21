{ pkgs, ... }:

let
  llamaCpp = pkgs.llama-cpp-rocm;

  qwenServer = pkgs.writeShellApplication {
    name = "ai-qwen";
    runtimeInputs = [ llamaCpp ];
    text = ''
      context="''${LLAMA_CONTEXT:-16384}"
      fit_target="''${LLAMA_FIT_TARGET:-2048}"
      host="''${LLAMA_HOST:-127.0.0.1}"
      port="''${LLAMA_PORT:-8080}"

      exec llama-server \
        -hf unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_M \
        --alias qwen3.6-35b-a3b \
        --no-mmproj \
        --ctx-size "$context" \
        --parallel 1 \
        --flash-attn auto \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --fit on \
        --fit-target "$fit_target" \
        --host "$host" \
        --port "$port" \
        "$@"
    '';
  };

  qwenMoeServer = pkgs.writeShellApplication {
    name = "ai-qwen-moe";
    runtimeInputs = [ llamaCpp ];
    text = ''
      context="''${LLAMA_CONTEXT:-16384}"
      cpu_moe="''${LLAMA_CPU_MOE:-12}"
      host="''${LLAMA_HOST:-127.0.0.1}"
      port="''${LLAMA_PORT:-8080}"

      exec llama-server \
        -hf unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_M \
        --alias qwen3.6-35b-a3b \
        --no-mmproj \
        --ctx-size "$context" \
        --parallel 1 \
        --flash-attn auto \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --n-gpu-layers 999 \
        --n-cpu-moe "$cpu_moe" \
        --fit off \
        --host "$host" \
        --port "$port" \
        "$@"
    '';
  };

  gemmaServer = pkgs.writeShellApplication {
    name = "ai-gemma";
    runtimeInputs = [ llamaCpp ];
    text = ''
      context="''${LLAMA_CONTEXT:-16384}"
      fit_target="''${LLAMA_FIT_TARGET:-2048}"
      host="''${LLAMA_HOST:-127.0.0.1}"
      port="''${LLAMA_PORT:-8080}"

      exec llama-server \
        -hf unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL \
        --alias gemma4-26b-a4b \
        --no-mmproj \
        --ctx-size "$context" \
        --parallel 1 \
        --flash-attn auto \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --fit on \
        --fit-target "$fit_target" \
        --host "$host" \
        --port "$port" \
        "$@"
    '';
  };
in
{
  home.packages = [
    llamaCpp
    pkgs.amdgpu_top
    qwenServer
    qwenMoeServer
    gemmaServer
  ];

  programs.bash.shellAliases = {
    ai-devices = "llama-server --list-devices";
    ai-gpu = "amdgpu_top";
  };
}
