{ inputs, pkgs, ... }:

let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # CCR 3.0.7 – self-contained expression, not an override of the llm-agents pin.
  # (The llm-agents flake is still pinned at 3.0.0, whose gateway had
  # stream-disconnect and OpenCode-Zen-400 bugs.)
  claudeCodeRouter = pkgs.callPackage ../../../packages/claude-code-router.nix { };

  # `ccr codex` is the only CCR surface kept. Claude Code needed one CCR
  # profile per model (its Anthropic translation layer cannot vary the context
  # window at runtime), which was brittle and is gone. Codex needs a single
  # profile: its model catalogue carries every model, so it switches itself.
  claudeCodeRouterCli = pkgs.writeShellApplication {
    name = "ccr";
    text = ''
      if [ "$#" -ge 1 ]; then
        case "$1" in
          codex | Codex | CODEX)
            shift
            exec ${claudeCodeRouter}/bin/ccr default-codex "$@"
            ;;
        esac
      fi
      exec ${claudeCodeRouter}/bin/ccr "$@"
    '';
  };

  # Discover the OpenCode Zen models that are free right now and write them
  # into CCR's Codex profile. `update-ai` and `update-system` run this after
  # rebuilding, so the list tracks OpenCode without hand-editing CCR.
  ccrModels = pkgs.writeShellApplication {
    name = "ccr-models";
    runtimeInputs = [ pkgs.python3 claudeCodeRouterCli ];
    text = ''
      exec python3 ${../../../scripts/ccr-models.py} "$@"
    '';
  };
in
{
  home.packages = [
    claudeCodeRouterCli
    ccrModels
    llmAgents.hermes-agent
    llmAgents.opencode
    (pkgs.callPackage ../../../packages/pi.nix {
      pi-src = inputs.pi;
    })
  ];
}
