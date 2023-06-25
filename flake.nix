{
  description = "Secret management with age";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus/?ref=refs/pull/120/head";
    flake-utils-plus.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils-plus,
    darwin,
    home-manager,
  }: let
    agenix = system: nixpkgs.legacyPackages.${system}.callPackage ./pkgs/agenix.nix {};
    doc = system: nixpkgs.legacyPackages.${system}.callPackage ./pkgs/doc.nix {};
    # Super Stupid Flakes (ssf) / System As an Input - Style:
    supportedSystems = flake-utils-plus.lib.defaultSystems;
  in {
    nixosModules.age = import ./modules/age.nix;
    nixosModules.default = self.nixosModules.age;

    darwinModules.age = import ./modules/age.nix;
    darwinModules.default = self.darwinModules.age;

    homeManagerModules.age = import ./modules/age-home.nix;
    homeManagerModules.default = self.homeManagerModules.age;

    overlays.default = import ./overlay.nix;

    formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.alejandra;
    packages.x86_64-darwin.agenix = agenix "x86_64-darwin";
    packages.x86_64-darwin.doc = doc "x86_64-darwin";
    packages.x86_64-darwin.default = self.packages.x86_64-darwin.agenix;

    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.alejandra;
    packages.aarch64-darwin.agenix = agenix "aarch64-darwin";
    packages.aarch64-darwin.doc = doc "aarch64-darwin";
    packages.aarch64-darwin.default = self.packages.aarch64-darwin.agenix;

    formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.alejandra;
    packages.aarch64-linux.agenix = agenix "aarch64-linux";
    packages.aarch64-linux.doc = doc "aarch64-linux";
    packages.aarch64-linux.default = self.packages.aarch64-linux.agenix;

    formatter.i686-linux = nixpkgs.legacyPackages.i686-linux.alejandra;
    packages.i686-linux.agenix = agenix "i686-linux";
    packages.i686-linux.doc = doc "i686-linux";
    packages.i686-linux.default = self.packages.i686-linux.agenix;

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
    packages.x86_64-linux.agenix = agenix "x86_64-linux";
    packages.x86_64-linux.default = self.packages.x86_64-linux.agenix;
    packages.x86_64-linux.doc = doc "x86_64-linux";

    checks =
      nixpkgs.lib.genAttrs ["aarch64-darwin" "x86_64-darwin"] (system: {
        integration =
          (darwin.lib.darwinSystem {
            inherit system;
            modules = [
              ./test/integration_darwin.nix
              "${darwin.outPath}/pkgs/darwin-installer/installer.nix"
              home-manager.darwinModules.home-manager
              {
                home-manager = {
                  verbose = true;
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "hmbak";
                  users.runner = ./test/integration_hm_darwin.nix;
                };
              }
            ];
          })
          .system;
      })
      // {
        x86_64-linux.integration = import ./test/integration.nix {
          inherit nixpkgs home-manager;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          system = "x86_64-linux";
        };
      };

    darwinConfigurations.integration-x86_64.system = self.checks.x86_64-darwin.integration;
    darwinConfigurations.integration-aarch64.system = self.checks.aarch64-darwin.integration;

    # Work-around for https://github.com/nix-community/home-manager/issues/3075
    legacyPackages = nixpkgs.lib.genAttrs supportedSystems (system: {
      homeConfigurations.integration-darwin = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [./test/integration_hm_darwin.nix];
      };
    });
  };
}
