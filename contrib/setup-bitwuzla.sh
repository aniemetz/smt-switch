#!/bin/bash
git_commit=ef068aa1c880a5cc7bfccf47679fbae20d300d2f

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
