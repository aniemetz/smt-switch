#!/bin/bash
git_commit=54f24172c21ef0466208bdd3d0919fc33740e39d

prepare_step() {
  "$contrib_dir/setup-cadical.sh"
}

configure_step() {
  ./configure.py --prefix "$install_dir"
}

download_step() {
  git clone --revision=$git_commit git@github.com:bitwuzla/bitwuzla-interpolants.git $dep_name
}
# shellcheck source=contrib/meson-setup.sh
source "$(dirname "$(realpath "$0")")/meson-setup.sh"
