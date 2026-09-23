{ inputs, pkgs, ... }:

let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # CCR 3.0.7 – self-contained expression, not an override of the llm-agents
  # pin: llm-agents' claude-code-router was too old when this was added (its
  # gateway had stream-disconnect and OpenCode-Zen-400 bugs).
  claudeCodeRouter = pkgs.callPackage ../../../packages/claude-code-router.nix { };

  # CCR is installed but intentionally left unconfigured: OpenCode Zen gates
  # its free tier to the OpenCode client, so nothing is wired to it. Configure
  # CCR with `ccr ui` once a provider that accepts external clients exists.
  # `ccr codex` stays a convenience alias for CCR's Codex profile.
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
in
{
  home.packages = [
    claudeCodeRouterCli
    (pkgs.callPackage ../../../packages/openchamber { })
    llmAgents.hermes-agent
    llmAgents.opencode
    (pkgs.callPackage ../../../packages/pi.nix {
      pi-src = inputs.pi;
    })
  ];

  # oh-my-pi (omp) is installed and kept current by its own Home Manager
  # module; settings are left to `omp setup` so onboarding stays writable.
  programs.omp.enable = true;
}
