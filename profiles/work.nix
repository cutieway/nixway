{ ... }:

{
  home-manager.sharedModules = [
    (
      { inputs, pkgs, ... }:
      {
        home.packages = [
          inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default
          pkgs.bun
          pkgs.gcc
          pkgs.openssl.dev
          pkgs.pkg-config
          pkgs.rustup
          pkgs.zed-editor
        ];

        home.sessionVariables = {
          OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
          OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
        };
      }
    )
  ];
}
