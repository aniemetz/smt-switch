#!/bin/bash
_version=2.1.3
git_tag=rel-$_version
github_owner=arminbiere

configure_step() {
  ./configure CXXFLAGS="-fPIC"
}

install_step() {
  # cvc5 looks for include/cadical/cadical.hpp and include/cadical/tracer.hpp,
  # while Boolector requires include/ccadical.h. Both find the library with
  # CMake's find_library, so there is no pkg-config file to install: Bitwuzla
  # was the only consumer of one, and it now builds its own CaDiCaL.
  install_cadical_includedir=$install_includedir/cadical
  install -d "$install_cadical_includedir" "$install_libdir"
  install -Cm644 src/ccadical.h "$install_includedir"
  install -Cm644 src/cadical.hpp "$install_cadical_includedir"
  install -Cm644 src/tracer.hpp "$install_cadical_includedir"
  install -Cm644 build/libcadical.a "$install_libdir"
}

# shellcheck source=contrib/make-setup.sh
source "$(dirname "$0")/make-setup.sh"
