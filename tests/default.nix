{
  inputs,
  lib,
  self,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      nixos-lib = import (pkgs.path + "/nixos/lib") { };
      flake = ../examples/flake-parts;
      agenix = (import "${flake}/flake.nix").outputs (inputs);
    in
    {
      checks = {
        flake-parts-template =
          (nixos-lib.runTest {
            hostPkgs = pkgs;
            name = "test1";
            #test = ../examples/flake-parts;
            # This speeds up the evaluation by skipping evaluating documentation (optional)
            defaults.documentation.enable = lib.mkDefault false;
            # This makes `self` available in the NixOS configuration of our virtual machines.
            # This is useful for referencing modules or packages from your own flake
            # as well as importing from other flakes.
            node.specialArgs = { inherit self; };
            nodes.node =
              { pkgs, ... }:
              {
                environment.etc.setupScript = {
                  mode = "777";
                  source = pkgs.writeText "test" ''
                    cp -r  ${flake} /tmp/test
                    chmod -R 777 /tmp/test
                    cd /tmp/test
                    export NIX_CONFIG="extra-experimental-features = flakes nix-command"
                    nix flake lock --offline --override-input agenix-rekey ${../.} ${
                      lib.concatMapAttrsStringSep " " (name: x: "--override-input ${name} ${x.outPath}") inputs
                    }

                  '';
                };
                environment.etc.testScript = {
                  mode = "777";
                  source = pkgs.writeText "test" ''
                    cd /tmp/test
                    export NIX_CONFIG="extra-experimental-features = flakes nix-command"
                    ${lib.getExe agenix.packages.${system}.agenix} rekey
                    #nix run --offline .#packages.${system}.agenix
                  '';
                };
              };
            testScript = ''
              node.wait_for_unit("multi-user.target")
              outp = node.succeed("/etc/setupScript")
              print(outp)
              outp = node.succeed("/etc/testScript")
              print(outp)
            '';
          }).config.result;

        # basic-template = flakeCheck {
        #   template = config.flake.templates.basic;
        # };
      };
    };
}
