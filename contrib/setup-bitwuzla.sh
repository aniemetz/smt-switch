#!/bin/bash
git_commit=b5a3b77a5609204c64725ab40c0975514eaf08f2

download_step() {
  git clone --revision=$git_commit git@github.com:mpreiner/bitwuzla.git $dep_name
}

# prepare_step() {
#   "$contrib_dir/setup-cadical.sh"
#   patch -p1 <"$contrib_dir/bitwuzla_libgmp.patch"
# }

source "$(dirname "$(realpath "$0")")/meson-steps.sh"
source "$(dirname "$(realpath "$0")")/common-setup.sh"
