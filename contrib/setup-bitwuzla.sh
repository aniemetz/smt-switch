#!/bin/bash
git_commit=c96711661e14877662c70550e6a315fa2817ebd7

download_step() {
  git clone --revision=$git_commit git@github.com:bitwuzla/bitwuzla.git $dep_name
}

# prepare_step() {
#   "$contrib_dir/setup-cadical.sh"
#   patch -p1 <"$contrib_dir/bitwuzla_libgmp.patch"
# }

source "$(dirname "$(realpath "$0")")/meson-steps.sh"
source "$(dirname "$(realpath "$0")")/common-setup.sh"
