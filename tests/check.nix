{
  runCommand,
  system,
  stdenv,
  lib,
  src,
  bubblewrap,
  git,
  coreutils,
  nix,
  bash,
  writeText,
  inputs,
  fetchFromGitHub,
  ...
}:
let
  agenix = fetchFromGitHub {
    owner = "ryantm";
    repo = "agenix";
    rev = "main";
    hash = "sha256-NA/FT2hVhKDftbHSwVnoRTFhes62+7dxZbxj5Gxvghs=";
  };
  command = writeText "test-script" ''
    cd ${src}
    nix flake lock --override-input "agenix" ${agenix} --override-input agenix-rekey ${agenix}
    nix run .#packages.${system}.agenix >&2
    exit 1
  '';
in
runCommand "test"
  {
    buildInputs = [
      (lib.mapAttrsToList (_: v: v.outPath) inputs)
    ];
  }
  ''
    ${lib.getExe bubblewrap} \
     --dir /tmp \
     --dev /dev \
     --proc /proc \
     --bind /build /build \
     --chdir /build \
     --setenv PATH "${
       lib.makeBinPath [
         git
         coreutils
         nix
       ]
     }" \
     --overlay-src ${src} \
     --tmp-overlay ${src} \
     --share-net \
     --setenv XDG_RUNTIME_DIR "/run/user/1000" \
     --setenv NIX_CONFIG "extra-experimental-features = flakes nix-command" \
     --ro-bind /nix/store /nix/store \
       ${lib.getExe bash} ${command} > $out
  ''
