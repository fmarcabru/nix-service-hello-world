{
    description = "FastAPI hello world";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        pyproject-nix = {
            url = "github:pyproject-nix/pyproject.nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        uv2nix = {
            url = "github:pyproject-nix/uv2nix";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.pyproject-nix.follows = "pyproject-nix";
        };

        pyproject-build-systems = {
            url = "github:pyproject-nix/build-system-pkgs";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.pyproject-nix.follows = "pyproject-nix";
            inputs.uv2nix.follows = "uv2nix";
        };
    };

    outputs = { self, nixpkgs, uv2nix, pyproject-nix, pyproject-build-systems, ... }:
        let
            inherit (nixpkgs) lib;
            systems = [ "x86_64-linux" "aarch64-linux" ];

            # read pyproject.toml + uv.lock from the repo once (architecture-independent)
            workspace = uv2nix.lib.workspace.loadWorkspace {
                workspaceRoot = ./.;
            };

            # Translate uv.lock into a nix overlay
            overlay = workspace.mkPyprojectOverlay {
                sourcePreference = "wheel";
            };

            forAllSystems = lib.genAttrs systems;

            perSystem = system:
                let
                    pkgs = nixpkgs.legacyPackages.${system};
                    python = pkgs.python312;

                    # Build the full python package set with the overlay applied
                    pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
                        inherit python;
                    }).overrideScope (
                        lib.composeManyExtensions [
                            pyproject-build-systems.overlays.default
                            overlay
                        ]
                    );

                    # the virtual env with app and dependencies
                    venv = pythonSet.mkVirtualEnv "fastapi-hello-env" workspace.deps.default;
                in
                {
                    # usable with nix run
                    package = pkgs.writeShellApplication {
                        name = "fastapi-hello";
                        runtimeInputs = [ venv ];
                        text = ''
                            exec uvicorn fastapi_hello.main:app --host 0.0.0.0 --port 8080
                        '';
                    };

                    # dev shell for nix develop
                    devShell = pkgs.mkShell {
                        packages = [
                            pkgs.uv
                            pkgs.python312
                            pkgs.pyright
                            pkgs.nodejs_22
                        ];
                        env = {
                            UV_PYTHON = "${pkgs.python312}/bin/python";
                            UV_PYTHON_DOWNLOADS = "never";
                        };
                    };
                };

        in
        {
            packages    = forAllSystems (system: { default = (perSystem system).package; });
            devShells   = forAllSystems (system: { default = (perSystem system).devShell; });

            # to install as a service
            nixosModules.default = import ./module.nix self;
        };
}
