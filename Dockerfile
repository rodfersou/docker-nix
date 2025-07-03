# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ENV PATH /nix/var/nix/profiles/default/bin:$PATH

RUN <<DOCKER_BEFORE       bash                                                                       \
 && <<\CONFIG_BASHRC      sed -r 's/^ {4}//;/^$/d;/^#/d' | cat >> ~/.bashrc                          \
 && <<\CONFIG_DIRENVRC    sed -r 's/^ {4}//;/^$/d;/^#/d' | cat >  ~/.direnvrc                        \
 && <<CONFIG_DIRENV_TOML  sed -r 's/^ {4}//;/^$/d;/^#/d' | cat >  ~/.config/direnv/direnv.toml       \
 && <<INSTALL_NIX         bash                                                                       \
 && <<CONFIG_FLOX         sed -r 's/^ {4}//;/^$/d;/^#/d' | cat >> /etc/nix/nix.conf                  \
 && <<\CONFIG_DIRENV_FLOX sed -r 's/^ {4}//;/^$/d;/^#/d' | cat > ~/.config/direnv/lib/flox-direnv.sh \
 && <<INSTALL_FLOX        bash                                                                       \
 && <<DOCKER_AFTER        bash


# DOCKER BEFORE
    # BASE UTILS
    apt update -y
    apt install -y \
        curl       \
        direnv     \
        git

    # DIRENV HOOK
    mkdir -p ~/.config/direnv/lib
DOCKER_BEFORE


# CONFIG BASHRC
    eval "$(direnv hook bash)"
CONFIG_BASHRC


# CONFIG DIRENVRC
    ENV_DIR=$(find_up ".envrc")
    export ENV_DIR=${ENV_DIR%/*}
    export CURRENT_DIR=$PWD

    cd $ENV_DIR
    use_nix
    cd $CURRENT_DIR

    alias_dir=$ENV_DIR/.direnv/aliases
    rm -rf "$alias_dir"
    export_alias() {
        local name=$1
        shift
        local target="$alias_dir/$name"
        mkdir -p "$alias_dir"
        PATH_rm "$alias_dir"
        PATH_add "$alias_dir"
        echo "#!/bin/bash -e" > "$target"
        echo "$@" >> "$target"
        chmod +x "$target"
    }

    export_alias See 'cat $(which $@)'
    export_alias Ns  'nix-env -qaP ".*$@.*"'
    export_alias Nss 'nix search nixpkgs $@'
CONFIG_DIRENVRC


# CONFIG DIRENV_TOML
    [whitelist]
    prefix = [ "/app" ]
CONFIG_DIRENV_TOML


# INSTALL NIX
    curl --proto '=https'                           \
         --tlsv1.2                                  \
         -sSf                                       \
         -L https://install.determinate.systems/nix \
    | sh -s                                         \
         -- install linux                           \
         --extra-conf "sandbox = false"             \
         --extra-conf "filter-syscalls = false"     \
         --init none                                \
         --no-confirm
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable unstable
    nix-channel --update
INSTALL_NIX


# CONFIG FLOX
    extra-trusted-substituters = https://cache.flox.dev
    extra-trusted-public-keys = flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=
CONFIG_FLOX


# CONFIG DIRENV FLOX
    function use_flox() {
        if [[ ! -d ".flox" ]]; then
            printf "direnv(use_flox): \`.flox\` directory not found\n" >&2
            printf "direnv(use_flox): Did you run \`flox init\` in this directory?\n" >&2
            return 1
        fi

        direnv_load flox activate "$@" -- "$direnv" dump

        if [[ $# == 0 ]]; then
            watch_dir ".flox/env/"
            watch_file ".flox/env.json"
            watch_file ".flox/env.lock"
        fi
    }
CONFIG_DIRENV_FLOX


# INSTALL FLOX
    nix profile install                              \
        --profile /nix/var/nix/profiles/default      \
        --experimental-features "nix-command flakes" \
        --accept-flake-config                        \
        'github:flox/flox'
INSTALL_FLOX


# DOCKER AFTER
    # CLEAN
    nix-collect-garbage -d
    apt-get clean
    apt-get autoremove -y
    rm -rf /var/lib/apt/lists/*
DOCKER_AFTER
