{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/23.05.tar.gz") {} }:

let
  my-python = pkgs.python3;
  python-with-my-packages = my-python.withPackages (p: with p;
  [
    jinja2
    seaborn
  ]);
in
pkgs.mkShell {
  name = "coyote-dpdk";
  runScript = "bash";

  buildInputs = with pkgs; [
    # --- from vFPIO/vfpio.nix ---
    coreutils
    git
    boost
    pahole

    cmake
    nasm
    binutils
    openssl
    zlib
    docker
    docker-compose
    kubectl
    usbutils
    pciutils
    curl
    fmt_9
    gzip
    scc
    gnumeric

    python3
    python-with-my-packages

    # --- DPDK and dependencies ---
    dpdk
    pkg-config
    numactl
    libpcap
  ];
  shellHook = ''
    PYTHONPATH=${python-with-my-packages}/${python-with-my-packages.sitePackages}
  '';
}
