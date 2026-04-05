# NixOS k3s server image built via streamLayeredImage.
#
# Produces a script that streams a Docker image to stdout.
# Usage:
#   nix build .#cluster-image
#   $(cat result) | docker load
#
{ pkgs }:

pkgs.dockerTools.streamLayeredImage {
  name = "brute-k3s";
  tag = "latest";

  contents = with pkgs; [
    k3s
    coreutils
    bash
    iptables
    iproute2
    util-linux     # mount, umount, nsenter
    procps         # ps, top
    kmod           # modprobe
    socat
    shadow         # useradd (k3s needs this)
    gzip
    findutils
    gnugrep
    gnused
  ];

  fakeRootCommands = ''
    mkdir -p ./etc ./tmp ./var/lib/rancher/k3s/server/manifests ./run
    echo "root:x:0:0:root:/root:/bin/bash" > ./etc/passwd
    echo "root:x:0:" > ./etc/group
  '';

  config = {
    Cmd = [
      "${pkgs.k3s}/bin/k3s" "server"
      "--disable" "traefik"
      "--disable" "metrics-server"
      "--tls-san" "127.0.0.1"
      "--tls-san" "host.docker.internal"
    ];
    ExposedPorts = {
      "6443/tcp" = {};
    };
    Env = [
      "PATH=${pkgs.lib.makeBinPath (with pkgs; [ k3s coreutils bash iptables iproute2 util-linux procps kmod socat findutils gnugrep gnused ])}"
    ];
  };
}
