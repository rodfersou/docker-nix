# syntax=docker/dockerfile:1
FROM alpine:latest

ENV PATH /nix/var/nix/profiles/default/bin:$PATH

RUN <<DOCKER_BEFORE      sh                                                                  \
 && <<\CONFIG_DIRENVRC   sed -r 's/^ {4}//;/^$/d;/^#/d' | cat > ~/.direnvrc                  \
 && <<CONFIG_DIRENV_TOML sed -r 's/^ {4}//;/^$/d;/^#/d' | cat > ~/.config/direnv/direnv.toml \
 && <<DOCKER_AFTER       sh

# DOCKER BEFORE
    # BASE UTILS
    apk add --no-cache curl

    # DIRENV HOOK
    echo 'eval "\$(direnv hook bash)"' >> ~/.bashrc
    mkdir -p ~/.config/direnv
DOCKER_BEFORE

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

# DOCKER AFTER
    # NIX
    curl --proto '=https'                           \
         --tlsv1.2                                  \
         -sSf                                       \
         -L https://install.determinate.systems/nix \
    | sh -s                                         \
         -- install linux                           \
         --extra-conf "sandbox = false"             \
         --init none                                \
         --no-confirm
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable unstable
    nix-channel --update
    nix-env -i direnv

    # CLEAN
    nix-collect-garbage -d
DOCKER_AFTER
