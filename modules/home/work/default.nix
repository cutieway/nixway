{ inputs, pkgs, pkgs-unstable, ... }:

let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # CCR 3.0.7 – self-contained expression, not an override of the llm-agents pin.
  # (The llm-agents flake is still pinned at 3.0.0, whose gateway had
  # stream-disconnect and OpenCode-Zen-400 bugs.)
  claudeCodeRouter = pkgs.callPackage ../../../packages/claude-code-router.nix { };

  # Ensure correct reasoning levels per model profile.
  # CCR's bundled gateway normalises effort via its Qt function:
  #   low/medium/high → "high"
  #   xhigh/max       → "max"
  # DeepSeek profiles use "xhigh" to get "max" reasoning, all others use "high".
  ccrSetReasoning = pkgs.writeShellApplication {
    name = "ccr-set-reasoning";
    text = ''
      # shellcheck shell=bash
      set -euo pipefail

      CCR_PROFILES="$HOME/.claude-code-router/profiles"

      updated=0
      for entry in "default-claude-code:xhigh" "claude-deepseek:xhigh" "claude-nemotron:high" "claude-north:high" "claude-mimo:high" "claude-big-pickle:high" "claude-laguna:high" "claude-ling:high"; do
        dir="''${entry%%:*}"
        want="''${entry##*:}"
        settings="$CCR_PROFILES/$dir/claude/settings.json"
        if [ -f "$settings" ]; then
          current=$(jq -r '.effortLevel // empty' "$settings" 2>/dev/null || true)
          if [ "$current" != "$want" ]; then
            jq --arg e "$want" '.effortLevel = $e' "$settings" > "$settings.tmp" \
              && mv "$settings.tmp" "$settings"
            echo "fixed: $dir  $current → $want"
            ((updated++))
          fi
        else
          echo "warning: $dir settings not found -- run 'ccr $dir setup' first"
        fi
      done

      if [ "$updated" -eq 0 ]; then
        echo "All profiles have correct effortLevel values."
      else
        echo "Updated $updated profile(s)."
      fi
    '';
  };

  claudeCodeRouterCli = pkgs.writeShellApplication {
    name = "ccr";
    text = ''
      if [ "$#" -ge 1 ] && [ "$1" = "claude" ]; then
        case "''${2-}" in
          "" | -h | --help)
            printf '%s\n' \
              'Usage: ccr claude-<profile> [cli|app] [-- <claude arguments>]' \
              'Available Claude Code profiles:' \
              '  ccr claude-deepseek    OpenCode Zen/deepseek-v4-flash-free    (200k context)' \
              '  ccr claude-nemotron    OpenCode Zen/nemotron-3-ultra-free     (1m context)' \
              '  ccr claude-north       OpenCode Zen/north-mini-code-free      (256k context)' \
              '  ccr claude-mimo        OpenCode Zen/mimo-v2.5-free            (200k context)' \
              '  ccr claude-big-pickle  OpenCode Zen/big-pickle                (200k context)' \
              '  ccr claude-laguna      OpenCode Zen/laguna-s-2.1-free         (128k context)' \
              '  ccr claude-ling        OpenCode Zen/ling-3.0-flash-free       (128k context)' \
              "" \
              'Choose a profile explicitly; ccr claude does not launch a model.'
            exit 0
            ;;
        esac
      fi

      exec ${claudeCodeRouter}/bin/ccr "$@"
    '';
  };
in
{
  home.packages = [
    # Keep AI agents together: they share the llm-agents flake pin and
    # are all advanced by update-ai.
    llmAgents.claude-code
    claudeCodeRouterCli
    ccrSetReasoning
    llmAgents.hermes-agent
    llmAgents.openclaw
    llmAgents.opencode
    llmAgents.opencode2
    pkgs.pi-coding-agent
    pkgs.bun
    pkgs.gcc
    pkgs.python3
    pkgs.openssl.dev
    pkgs.pkg-config
    pkgs.rustup
  ];

  # Match the desktop's Original New UI Dark source theme. Settings stay
  # mutable so Zed can preserve Lexi's other editor preferences.
  programs.zed-editor = {
    enable = true;
    package = pkgs-unstable.zed-editor;
    extensions = [
      "jetbrains-themes"
      "jetbrains-new-ui-icons"
    ];
    userSettings = {
      icon_theme = "JetBrains New UI Icons (Dark)";
      theme = {
        mode = "system";
        light = "One Light";
        dark = "JetBrains Dark";
      };
    };
  };

  home.sessionVariables = {
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  };
}
