self:
{ conig, lib, pkgs, ... }:
let 
    cfg = config.services.fastapi-hello;
in
{
    options.services.fastapi-hello = {
        enable = lib.mkEnableOption "FastAPI hello world service";

        port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
            description = "Port to listen on";
        };

        openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Open firewall for the service port";
        };
    };

    config = lib.mkIf cfg.enable {
        networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

        systemd.services.fastapi-hello = {
            description = "FastAPI hello world";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];

            serviceConfig = {
                ExecStart = "${self.packages.${pkgs.system}.default}/bin/fastapi-hello";
                Restart= "on-failure";
                RestartSec = 5;
                DynamicUser = true;
                ProvateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
                NoNewPrivileges = true;
            };
        };
    };
}
