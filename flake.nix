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
            system = "x86_64-linux";
            pkgs = nixpkgs.legacyPackages.${system};
        in
        {
            devShells.${system}.default = pkgs.mkShell {
                packages = [
                    pkgs.uv
                    pkgs.python312
                    pkgs.pyright
                ];
            env = {
                UV_PYTHON = "${pkgs.python312}/bin/python";
                UV_PYTHON_DOWNLOADS = "never";
            };
        };
    };
}
