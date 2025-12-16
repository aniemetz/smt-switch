#!/bin/bash
git_commit=64dee7007aa0092c87dab171ea199c14f3a608a9

download_step() {
  git clone --revision=$git_commit git@github.com:aniemetz/bitwuzla-private.git $dep_name
}

# prepare_step() {
#   "$contrib_dir/setup-cadical.sh"
#   patch -p1 <"$contrib_dir/bitwuzla_libgmp.patch"
# }

source "$(dirname "$(realpath "$0")")/meson-steps.sh"
source "$(dirname "$(realpath "$0")")/common-setup.sh"
