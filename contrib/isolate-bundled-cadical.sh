#!/bin/bash
#
# Bitwuzla builds the CaDiCaL of subprojects/cadical.wrap and links it
# straight into libbitwuzla.a. That copy is patched and newer than the
# CaDiCaL that contrib/setup-cadical.sh installs for Boolector and cvc5, yet
# both define the same CaDiCaL::* symbols, so an executable that links two
# smt-switch backends fails with duplicate symbol errors. Neither copy can be
# dropped: Bitwuzla requires CaDiCaL 3.0 or newer, cvc5 supports at most
# 2.1.3, and the patches are what keep Bitwuzla's ADC SAT propagator and SAT
# decision heuristics enabled.
#
# Renaming Bitwuzla's symbols lets both versions coexist. Three things about
# how that is done here are load-bearing:
#
#   * The rename happens in one relocatable object, because renaming per
#     archive member would leave the references from Bitwuzla's own objects
#     pointing at the old names.
#   * Only the symbols that the bundled CaDiCaL alone defines are renamed.
#     Its objects also emit the standard library templates they instantiate,
#     and those are the same code in every copy, so renaming them would only
#     take definitions away from whoever else needs them.
#   * The COMDAT group signatures are renamed along with the symbols. GCC
#     names the group of a constructor or destructor after its unified C5/D5
#     variant, which is not a symbol nm lists, so renaming only the members
#     leaves the group still answering to its old signature. The final link
#     then drops another object's identically signed group, that object loses
#     the definitions it was relying on, and the call goes to an undefined
#     weak symbol, that is a null pointer. Renaming the signature keeps the
#     groups apart. This is invisible in a release build, where the bodies in
#     question are inlined, and crashes a debug one on startup.
#
# Localizing the symbols instead of renaming them fails for the same reason
# and cannot be repaired the same way: the group that survives is the one
# whose symbols are no longer reachable.
#
# Usage: isolate-bundled-cadical.sh <libbitwuzla.a> <bundled libcadical.a>
set -e          # exit on error
set -u          # unset variable raises error
set -o pipefail # exit if an intermediate command in a pipe fails

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <libbitwuzla.a> <bundled libcadical.a>" >&2
  exit 1
fi
bitwuzla_lib=$(realpath "$1")
cadical_lib=$(realpath "$2")

# Mach-O prepends an underscore to every symbol, so a prefix that started
# with one would collide with the identifiers reserved for the toolchain.
prefix=bzla_bundled_

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# Bitwuzla installs its internal libraries next to the one being isolated and
# links them alongside it, so their references have to keep resolving.
lib_dir=$(dirname "$bitwuzla_lib")
sibling_libs=()
for lib in "$lib_dir"/libbitwuzla*.a; do
  if [[ $lib != "$bitwuzla_lib" ]]; then
    sibling_libs+=("$lib")
  fi
done

# nm prints "<address> <type> <name>" and gives the global symbols an
# upper-case type. The archive member headers it interleaves are a single
# field, and an undefined symbol has no address, so both are dropped here.
# Both helpers are called in pipelines rather than command substitutions,
# which would silence a failure of nm itself (SC2311).
list_defined() {
  nm -g --defined-only "$@" | awk 'NF >= 3 && $2 ~ /^[A-Z]$/ { print $3 }'
}
list_undefined() {
  nm -u "$@" | awk 'NF == 2 { print $2 }'
}

# Split the archive by provenance. Members are matched by name, so bail out
# rather than guess if a name is not unique; the CaDiCaL archive is thin and
# lists its members by path.
ar t "$bitwuzla_lib" | sort >"$tmp_dir/members"
uniq -d <"$tmp_dir/members" >"$tmp_dir/members-duplicated"
if [[ -s $tmp_dir/members-duplicated ]]; then
  echo "$0: $bitwuzla_lib has members that share a name:" >&2
  cat "$tmp_dir/members-duplicated" >&2
  exit 1
fi
ar t "$cadical_lib" | sed 's|.*/||' | sort -u >"$tmp_dir/cadical-members"
comm -12 "$tmp_dir/members" "$tmp_dir/cadical-members" \
  >"$tmp_dir/members-cadical"
if [[ ! -s $tmp_dir/members-cadical ]]; then
  echo "$0: no object of $cadical_lib is part of $bitwuzla_lib" >&2
  exit 1
fi

# What is left once the CaDiCaL objects are gone is Bitwuzla's own code.
cp "$bitwuzla_lib" "$tmp_dir/own.a"
tr '\n' '\0' <"$tmp_dir/members-cadical" | xargs -0 ar d "$tmp_dir/own.a"

# The symbols only the bundled CaDiCaL defines, plus the CaDiCaL symbols that
# Bitwuzla's own translation units emit: inline functions, typeinfos and
# vtables. Bitwuzla's own bzla:: symbols stay as they are, they cannot clash
# with cvc5, and DW.ref.* has to keep its name for the unwinder to find it.
list_defined "$cadical_lib" | sort -u >"$tmp_dir/cadical-defined"
list_defined "$tmp_dir/own.a" "${sibling_libs[@]}" |
  sort -u >"$tmp_dir/bitwuzla-defined"
comm -23 "$tmp_dir/cadical-defined" "$tmp_dir/bitwuzla-defined" \
  >"$tmp_dir/symbols-unsorted"
list_defined "$bitwuzla_lib" |
  awk '/7CaDiCaL/ && !/4bzla/' >>"$tmp_dir/symbols-unsorted"
awk '!/^DW\.ref\./' "$tmp_dir/symbols-unsorted" | sort -u >"$tmp_dir/symbols"
num_symbols=$(awk 'END { print NR }' "$tmp_dir/symbols")
echo "-- isolating $num_symbols CaDiCaL symbols in $bitwuzla_lib"

# Everything the two linkers do not have in common lives in these functions.
# isolate() turns <archive> plus <symbol file> into <relocatable object>,
# relink() puts <isolated archive> and the <sibling archives> back together
# the way a consumer links them.
case $OSTYPE in
  linux* | cygwin*)
    isolate() {
      ld -r --whole-archive "$1" -o "$tmp_dir/combined.o"
      # Group signatures are the symbols nm -a reports without a section; see
      # the note on COMDAT groups above for why they are renamed too.
      # Renaming the signature of a group whose members keep their names is
      # harmless: it only stops that group from being merged with an
      # identical one.
      nm -a "$tmp_dir/combined.o" |
        awk '$2 == "n" && $3 ~ /^_Z/ { print $3 }' >>"$2"
      sort -u -o "$2" "$2"
      awk -v p="$prefix" '{ print $1, p $1 }' "$2" >"$tmp_dir/rename-map"
      objcopy --redefine-syms="$tmp_dir/rename-map" "$tmp_dir/combined.o" "$3"
    }
    relink() {
      ld -r --whole-archive "$1" --no-whole-archive "${@:2}" \
        -o "$tmp_dir/trial.o"
    }
    ;;
  darwin*)
    # macOS ships no objcopy, so hide the symbols rather than rename them.
    # Mach-O has no COMDAT groups, and a private extern symbol takes part in
    # neither weak definition coalescing nor symbol resolution, so cvc5 keeps
    # the copy that the ELF caveat above would have cost it.
    isolate() {
      ld -r -all_load -unexported_symbols_list "$2" -o "$3" "$1"
    }
    relink() {
      ld -r -force_load "$1" "${@:2}" -o "$tmp_dir/trial.o"
    }
    ;;
  *)
    echo "$0: unsupported OSTYPE=$OSTYPE" >&2
    exit 1
    ;;
esac

isolate "$bitwuzla_lib" "$tmp_dir/symbols" "$tmp_dir/isolated.o"

isolated_lib=$tmp_dir/isolated.a
ar cr "$isolated_lib" "$tmp_dir/isolated.o"
ranlib "$isolated_lib"

# An isolation that quietly did nothing would only surface much later, as
# duplicate symbols in a downstream link, so check it before installing it.
# A renamed symbol still reads as a CaDiCaL one, hence the prefix filter, and
# the bzla:: symbols that merely take a CaDiCaL argument are left alone above.
list_defined "$isolated_lib" |
  awk -v p="$prefix" '/CaDiCaL|cadical|ipasir_/ && !/4bzla/ &&
                      $0 !~ "^_*" p' >"$tmp_dir/leaked"
if [[ -s $tmp_dir/leaked ]]; then
  echo "$0: these CaDiCaL symbols were not isolated:" >&2
  cat "$tmp_dir/leaked" >&2
  exit 1
fi

# An isolation that took away a definition someone still needs would be worse
# than none at all, and no symbol listing shows that: a group dropped for a
# signature clash counts as defined right up to the link. So relink the
# libraries the way a consumer does and compare what that leaves undefined.
list_defined "$bitwuzla_lib" "${sibling_libs[@]}" |
  sort -u >"$tmp_dir/defined-before"
relink "$isolated_lib" "${sibling_libs[@]}"
list_undefined "$tmp_dir/trial.o" | sort -u >"$tmp_dir/trial-undefined"
comm -12 "$tmp_dir/trial-undefined" "$tmp_dir/defined-before" \
  >"$tmp_dir/regressed"
if [[ -s $tmp_dir/regressed ]]; then
  echo "$0: isolating CaDiCaL left these symbols undefined:" >&2
  cat "$tmp_dir/regressed" >&2
  exit 1
fi

mv "$isolated_lib" "$bitwuzla_lib"
