#!/bin/bash
git_commit=032e99cefaf53d82edb20425190b0232bc7f8ecb

download_step() {
  git clone --revision=$git_commit git@github.com:mpreiner/bitwuzla.git $dep_name
}
prepare_step() {
  "$contrib_dir/setup-cadical.sh"
}

# shellcheck source=contrib/meson-setup.sh
source "$(dirname "$(realpath "$0")")/meson-setup.sh"
