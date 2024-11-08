{
  description = "A disko images example";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    terranix,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
        # ...
      ];
      imports = [
        inputs.devshell.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.nix-topology.flakeModule
      ];
      flake = {
        nixosConfigurations.peter = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            "${nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
            {
              amazonImage.sizeMB = "auto";
              services = {
                nginx.enable = true;
                openssh = {
                  enable = true;
                  settings = {
                    PasswordAuthentication = false;
                    KbdInteractiveAuthentication = false;
                    # PermitRootLogin = "no";
                  };
                };
              };
            }
          ];
        };
      };
      perSystem = {
        config,
        system,
        pkgs,
        lib,
        self',
        ...
      }: {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (lib.getName pkg) [
              "terraform"
            ];
        };
        apps = let
          terraformWithPlugins = pkgs.terraform.withPlugins (plugins: [
            pkgs.terraform-providers.null
          ]);
          tfBin = lib.getExe terraformWithPlugins;
          outJson = "config.tf.json";
          terraformConfiguration = terranix.lib.terranixConfiguration {
            inherit system;
            modules = [
              (import ./terraform/flake-module.nix
                {
                  specialArgs = {
                    imagePath = self.nixosConfigurations.peter.config.system.build.amazonImage;
                  };
                })
            ];
          };
          makeTfApp = verb: {
            type = "app";
            program = toString (pkgs.writers.writeBash "${verb}" ''
              if [[ -e ${outJson} ]]; then rm -f ${outJson}; fi
              cp ${terraformConfiguration} ${outJson} \
                && ${tfBin} init \
                && ${tfBin} ${verb}
            '');
          };
        in {
          apply = makeTfApp "apply";
          plan = makeTfApp "plan";
          destroy = makeTfApp "destroy";
        };
        devshells.default = {
          packages = with pkgs; [
            awscli2
          ];
        };
        devshells.tf = {
          imports = [
            ./shells/terraform.nix
          ];
        };
        treefmt = {
          projectRootFile = "flake.nix";
          programs = {
            alejandra.enable = true;
            shellcheck.enable = true;
            shfmt.enable = true;
            terraform = {
              enable = true;
              package = pkgs.terraform;
            };
            typos.enable = true;
          };
          settings = {
            formatter.shellcheck.options = ["--external-sources"];
          };
        };
      };
    };
}
