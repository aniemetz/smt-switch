#!/bin/bash
git_commit=ba59f83e436aafa0717e619c49345848dd1cebd5

configure_step() {
  ./configure.py --prefix "$install_dir"
}

download_step() {
  git clone --revision=$git_commit git@github.com:bitwuzla/bitwuzla-interpolants.git $dep_name
}

install_step() {
  meson install -C build

  # Bitwuzla links the CaDiCaL of its cadical.wrap into libbitwuzla.a, where
  # it clashes with the CaDiCaL that contrib/setup-cadical.sh installs for
  # Boolector and cvc5. The glob misses if Bitwuzla found a system-wide
  # CaDiCaL instead, and then there is nothing to isolate.
  bundled_cadical_lib=(build/subprojects/cadical-*/src/libcadical.a)
  installed_lib=$install_libdir/libbitwuzla.a
  if [[ -f ${bundled_cadical_lib[0]} && -f $installed_lib ]]; then
    "$contrib_dir/isolate-bundled-cadical.sh" \
      "$installed_lib" "${bundled_cadical_lib[0]}"
  fi
}

_setup_script_path=$(realpath "$0")

# shellcheck source=contrib/meson-setup.sh
source "$(dirname "$_setup_script_path")/meson-setup.sh"
