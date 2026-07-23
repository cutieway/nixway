{ ... }:

{
  home-manager.sharedModules = [
    (
      { inputs, pkgs, pkgs-unstable, ... }:
      let
        llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      in
      {
        home.packages = [
          # Keep AI agents together: they share the llm-agents flake pin and
          # are all advanced by update-ai.
          llmAgents.hermes-agent
          llmAgents.opencode
          llmAgents.opencode2
          pkgs.bun
          pkgs.gcc
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
    )
  ];
}
