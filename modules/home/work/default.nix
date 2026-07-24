{ inputs, pkgs, pkgs-unstable, ... }:

let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # CCR 3.0 records DeepSeek V4 Flash's high/max tiers in reasoningOptions,
  # but its Codex catalog only checks this flattened capability when deciding
  # whether to expose xhigh. Its bundled DeepSeek middleware also applies the
  # high/max clamp to every model from the same provider. Keep both fixes
  # narrowly scoped to the OpenCode Zen free models configured in CCR.
  claudeCodeRouter = llmAgents.claude-code-router.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
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

      node - "$package/node_modules/@the-next-ai/ai-gateway/dist/index.js" <<'NODE'
      const fs = require("fs");
      const gatewayPath = process.argv[2];
      let source = fs.readFileSync(gatewayPath, "utf8");

      const transformNeedle =
        'let t=dS(e,n),r=cS(e,n);return';
      const transformReplacement =
        'if(!ccrZenFreeModel(n.model))return{ok:!0,value:e.upstreamRequest};' +
        'let t=dS(e,n),r=ccrZenEffort(n.model,cS(e,n));return';

      const effortNeedle =
        'function Gt(e){if(typeof e!="string")return;let n=e.trim().toLowerCase().replace(/[-_\\s]+/g,"");' +
        'if(n==="max"||n==="xhigh")return"max";' +
        'if(n==="high"||n==="medium"||n==="low")return"high"}function Kg(e)';
      const effortReplacement =
        'function Gt(e){if(typeof e!="string")return;let n=e.trim().toLowerCase().replace(/[-_\\s]+/g,"");' +
        'if(n==="max"||n==="xhigh"||n==="ultracode")return"max";' +
        'if(n==="high")return"high";' +
        'if(n==="medium")return"medium";' +
        'if(n==="low"||n==="minimal"||n==="none")return"low"}' +
        'function ccrZenModelId(e){return typeof e==="string"?e.trim().toLowerCase().split("/").pop():""}' +
        'function ccrZenFreeModel(e){return new Set([' +
        '"deepseek-v4-flash-free","nemotron-3-ultra-free","laguna-s-2.1-free",' +
        '"north-mini-code-free","mimo-v2.5-free","big-pickle"' +
        ']).has(ccrZenModelId(e))}' +
        'function ccrZenEffort(e,n){if(!n)return;let t=ccrZenModelId(e);' +
        'if(t==="deepseek-v4-flash-free")return n==="max"?"max":n==="high"?"high":"medium";' +
        'return n==="max"||n==="high"?"high":"medium"}' +
        'function Kg(e)';

      for (const [needle, replacement, label] of [
        [transformNeedle, transformReplacement, "free-model scope"],
        [effortNeedle, effortReplacement, "effort mapping"]
      ]) {
        const matches = source.split(needle).length - 1;
        if (matches !== 1) {
          throw new Error(`Expected one CCR Zen ''${label} patch point, found ''${matches}`);
        }
        source = source.replace(needle, replacement);
      }

      fs.writeFileSync(gatewayPath, source);
      NODE
    '';
  });

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
