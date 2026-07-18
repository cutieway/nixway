{
  bzip2,
  buildFHSEnv,
  elfutils,
  fetchurl,
  gnutar,
  iproute2,
  iptables,
  lib,
  ncurses,
  nettools,
  networkmanager,
  openssl,
  procps,
  stdenvNoCC,
  zlib,
}:

let
  pname = "mudfish";
  version = "6.5.3";

  unwrapped = stdenvNoCC.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://mudfish.net/releases/mudfish-${version}-linux-x86_64.sh";
      hash = "sha256-WJaYhdHCKoRXnBFESanFnsFo8fOnPEg6PG8N+0/zuBg=";
    };

    nativeBuildInputs = [
      bzip2
      gnutar
    ];

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      sh "$src" --noexec --target "$PWD/unpacked"
      mkdir -p "$out/opt/mudfish/${version}"
      cp -a "$PWD/unpacked/." "$out/opt/mudfish/${version}/"

      # Mudfish writes runtime state below its versioned installation tree.
      # The FHS wrapper overlays this empty directory with /var/lib/mudfish.
      mkdir -p "$out/opt/mudfish/${version}/var"

      runHook postInstall
    '';

    meta = {
      description = "Mudfish game network accelerator binaries";
      homepage = "https://mudfish.net";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
buildFHSEnv {
  inherit pname version;

  # Mudfish hard-codes both its /opt installation path and conventional Linux
  # command locations. Keep that compatibility layout private to Mudfish.
  runScript = "/opt/mudfish/${version}/bin/mudrun-headless";
  extraBwrapArgs = [
    "--ro-bind ${unwrapped}/opt /opt"
    "--bind /var/lib/mudfish /opt/mudfish/${version}/var"
  ];

  extraBuildCommands = ''
    mkdir -p "$out/usr/bin" "$out/usr/sbin"
    ln -s ${networkmanager}/bin/nmcli "$out/usr/bin/nmcli"
    ln -s ${iproute2}/bin/ip "$out/usr/sbin/ip"
    ln -s ${iptables}/bin/iptables "$out/usr/sbin/iptables"
    ln -s ${procps}/bin/sysctl "$out/usr/sbin/sysctl"
    ln -s ${nettools}/bin/ifconfig "$out/usr/sbin/ifconfig"
    ln -s ${nettools}/bin/route "$out/usr/sbin/route"
  '';

  targetPkgs = _: [
    elfutils
    ncurses
    openssl
    zlib
  ];

  passthru = { inherit unwrapped; };

  meta = {
    description = "Headless Mudfish game network accelerator";
    homepage = "https://mudfish.net";
    license = lib.licenses.unfree;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
