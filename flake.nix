# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Unikie

{
  description = "A compartmentalized operating system";

  # NOTE: Revision specification format is ?ref=refs%2fheads%2f<BRANCH>&rev=<COMMIT_REVISION>
  inputs.nixpkgs.url =
    "git+https://spectrum-os.org/git/nixpkgs/?ref=refs%2fheads%2frootfs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  nixConfig = {
    extra-substituters = [ "https://cache.dataaturservice.se/spectrum/" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "spectrum-os.org-1:rnnSumz3+Dbs5uewPlwZSTP0k3g/5SRG4hD7Wbr9YuQ="
    ];
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      supportedSystems = with flake-utils.lib.system; [ x86_64-linux aarch64-linux ];
    in flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        config = { inherit pkgs; };
        lib = pkgs.lib;

        mkEntryPoint = { name ? builtins.baseNameOf path, path
          , enableShell ? true, enablePackage ? true }:
          let
            shell = {
              # NOTE: https://stackoverflow.com/a/43850372
              devShells.${name} =
                import (path + "/shell.nix") { inherit config; };
            };
            package = { packages.${name} = import path { inherit config; }; };
          in (if enableShell then shell else { })
          // (if enablePackage then package else { });

        # Entry point is a directory with shell.nix and default.nix
        # This function maps every entry point to corresponding devShell and package
        mapEntryPoints = epoints:
          builtins.foldl' lib.recursiveUpdate { } (map mkEntryPoint epoints);
      in lib.recursiveUpdate (mapEntryPoints [
        {
          path = ./.;
          enablePackage = false;
        }
        { path = ./host/initramfs; }
        { path = ./host/rootfs; }
        { path = ./host/start-vm; }
        { path = ./img/app; }
        { path = ./release/live; }
        { path = ./vm/sys/net; }
      ]) {
        # Add some other flake schema related stuff here.
        # NOTE: flake-utils.lib.eachDefaultSystem automagically adds ${system}.
        devShells.documentation = import ./Documentation { inherit config; };
        packages.documentation = import ./Documentation { inherit config; };
      });
}
