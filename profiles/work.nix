{ ... }:

{
  home-manager.sharedModules = [
    (
      { inputs, pkgs, pkgs-unstable, ... }:
      let
        llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
        claudeCodeRouter = llmAgents.claude-code-router.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            # CCR 3.0 records DeepSeek V4 Flash's high/max tiers in
            # reasoningOptions, but its Codex catalog only checks this
            # flattened capability when deciding whether to expose xhigh.
            package="$out/lib/node_modules/claude-code-router"
            for catalog in "$package/models.json" "$package/dist/models.json"; do
              node - "$catalog" <<'NODE'
            const fs = require("fs");
            const catalogPath = process.argv[2];
            const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
            const model = catalog.models.find(
              (entry) => entry.id === "deepseek/deepseek-v4-flash-free"
            );

            if (!model) {
              throw new Error("DeepSeek V4 Flash is missing from CCR's model catalog");
            }

            model.capabilities.maxReasoningEffort = true;
            fs.writeFileSync(catalogPath, `''${JSON.stringify(catalog, null, 2)}\n`);
            NODE
            done
          '';
        });
      in
      {
        home.packages = [
          # Keep AI agents together: they share the llm-agents flake pin and
          # are all advanced by update-ai.
          llmAgents.claude-code
          claudeCodeRouter
          llmAgents.hermes-agent
          llmAgents.openclaw
          llmAgents.opencode
          llmAgents.opencode2
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
    )
  ];
}
