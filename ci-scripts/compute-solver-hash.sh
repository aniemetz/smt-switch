#!/usr/bin/env bash
set -euo pipefail
gethash() {
  sha256sum "$1" | cut -d ' ' -f 1
}
solver=$1
solver_hash=$(gethash ci-scripts/setup-"$1".sh)
# The installed packages decide what the solver builds against
# shellcheck disable=SC2154 # RUNNER_LABEL is set by the workflow
solver_hash+=$(gethash ci-scripts/install-packages-"${RUNNER_LABEL%%-*}".sh)
if [[ $solver =~ ^(bitwuzla|btor|cvc5|z3)$ ]]; then
  solver_hash+=$(gethash contrib/common-setup.sh)
  if [[ $solver == bitwuzla ]]; then
    solver_hash+=$(gethash contrib/meson-setup.sh)
    # Bitwuzla brings its own CaDiCaL, which this renames after the install
    solver_hash+=$(gethash contrib/isolate-bundled-cadical.sh)
  else
    solver_hash+=$(gethash contrib/cmake-setup.sh)
  fi
  # Boolector and cvc5 are the solvers built against our CaDiCaL
  if [[ $solver =~ ^(btor|cvc5)$ ]]; then
    solver_hash+=$(gethash contrib/setup-cadical.sh)
    solver_hash+=$(gethash contrib/make-setup.sh)
  fi
fi
if [[ $solver == btor ]]; then
  solver_hash+=$(gethash contrib/setup-btor2tools.sh)
fi
result=$(gethash <(echo "$solver_hash"))
echo "result=$result" >>"${GITHUB_OUTPUT:?}"
