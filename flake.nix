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
            system = "x86_64-linux";
            pkgs = nixpkgs.legacyPackages.${system};
            python = pkgs.python312;

            # read pyproject.toml + uv.loc from the repo
            workspace = uv2nix.lib.workspace.loadWorkspace {
                workspaceRoot = ./.;
            };

            # Translate uv.lock in to a nix overlay
            overlay = workspace.mkPyprojectOverlay {
                sourcePreference = "wheel";
            };

            # Build the full python package set with the overlay applied
            pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
                inherit python;
                }).overrideScope (
                    lib.composeManyExtensions [
                        pyproject-build-systems.overlays.default
                        overlay
                    ]
                );
            # the virtual env wih app and dependencies
            venv = pythonSet.mkVirtualEnv "fastapi-hello-env" workspace.deps.default;

        in
        {
            # with with nix run
            packages.${system}.default = pkgs.writeShellApplication {
                name = "fastapi-hello";
                runtimeInputs = [ venv ];
                text = ''
                    exec uvicorn fastapi_hello.main:app --host 0.0.0.0 --port 8080
                '';
            };

            # dev shell for nix develop
            devShells.${system}.default = pkgs.mkShell {
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
}
