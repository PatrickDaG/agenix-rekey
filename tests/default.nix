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
      testFlake = ./cases/flake-parts;
      agenix = callFlake "${testFlake}/flake.nix";
      callFlake =
        src:
        lib.fix (
          flake:
          (import src).outputs (
            inputs
            // {
              self = flake // {
                inherit inputs;
                outPath = "${testFlake}";
              };
            }
          )
        );
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
                    cp -r  ${testFlake} /tmp/test
                    chmod -R 777 /tmp/test
                    cd /tmp/test
                    export NIX_CONFIG="extra-experimental-features = flakes nix-command"
                    nix flake lock --offline --override-input agenix-rekey ${../.} ${
                      lib.concatMapAttrsStringSep " " (name: x: "--override-input ${name} ${x.outPath}") (
                        lib.filterAttrs (name: _: name != "self" && name !="agenix-rekey") inputs
                      )
                    }

                  '';
                };
                environment.etc.testScript = {
                  mode = "777";
                  source = lib.getExe (
                    pkgs.writeShellApplication {
                      name = "test";
                      runtimeInputs = [
                        # # Don't actually use this. It's just to make sure the dependencies
                        # # are in the nix store of the vm
                        agenix.packages.${system}.agenix
                        agenix.agenix-rekey.${system}.rekey
                        # For writeshellapplication
                        pkgs.shellcheck-minimal
                        pkgs.shellcheck-minimal
                        # # Force the dependencies to also be part of the store
                        agenix.agenix-rekey.${system}.rekey.drvPath
                      ];
                      text = ''
                        cd /tmp/test
                        export NIX_CONFIG="extra-experimental-features = flakes nix-command"
                        ls -lah "$(which shellcheck)"
                        alias nix="nix --offline"
                        nix run --offline .#packages.${system}.agenix -- rekey
                        nix eval --offline .#nixosConfigurations.node.${system}.config.system.activationScripts.agenixNewGeneration.text | bash
                        nix eval --offline .#nixosConfigurations.node.${system}.config.system.activationScripts.agenixInstall.text | bash
                        cat /run/agenix/root-pw-hash
                      '';
                    }
                  );
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
