#!/bin/bash
git_commit=2e7204ac7344947d5f8ee1eb8b3812ec9981cedf

download_step() {
  git clone --revision=$git_commit git@github.com:mpreiner/bitwuzla.git $dep_name
}

# prepare_step() {
#   "$contrib_dir/setup-cadical.sh"
#   patch -p1 <"$contrib_dir/bitwuzla_libgmp.patch"
# }

source "$(dirname "$(realpath "$0")")/meson-steps.sh"
source "$(dirname "$(realpath "$0")")/common-setup.sh"
