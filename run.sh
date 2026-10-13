#!/bin/sh
# Reproduce libelfin's value::as_string abort on a zero-length DWARF string.
#
#   ./run.sh                      # unfixed libelfin: aborts
#   LIBELFIN_REV=<sha> ./run.sh   # e.g. the fix: passes
#
# Needs only git and a C++ compiler. No distribution packages.
set -eu
cd "$(dirname "$0")"

# plasma-umass/libelfin master keeping the unguarded call.
LIBELFIN_REV=${LIBELFIN_REV:-8d6cfef453613423a12a5f6d7b0d868bfb8763d6}
CXX=${CXX:-c++}
FIXTURE=fixture/empty-attr.o

if [ ! -e "$FIXTURE" ]; then
    echo "== assembling the fixture =="
    cc -c fixture/empty-attr.s -o "$FIXTURE"
fi

if [ ! -d libelfin/.git ]; then
    echo "== cloning libelfin =="
    git clone https://github.com/plasma-umass/libelfin.git libelfin
fi
echo "== checking out libelfin $LIBELFIN_REV =="
git -C libelfin fetch -q --all || true
# The fixing commit lives on the PR branch, not yet in plasma-umass/libelfin.
if ! git -C libelfin cat-file -e "$LIBELFIN_REV^{commit}" 2>/dev/null; then
    git -C libelfin fetch -q https://github.com/iacore/libelfin.git \
        fix-value-as-string-empty 2>/dev/null || true
fi
git -C libelfin checkout -q "$LIBELFIN_REV"

SOURCES="
libelfin/elf/elf.cc
libelfin/elf/mmap_loader.cc
libelfin/elf/to_string.cc
libelfin/dwarf/abbrev.cc
libelfin/dwarf/attrs.cc
libelfin/dwarf/cursor.cc
libelfin/dwarf/die.cc
libelfin/dwarf/die_str_map.cc
libelfin/dwarf/dwarf.cc
libelfin/dwarf/elf.cc
libelfin/dwarf/expr.cc
libelfin/dwarf/line.cc
libelfin/dwarf/rangelist.cc
libelfin/dwarf/to_string.cc
libelfin/dwarf/value.cc
"

echo "== building repro =="
# -D_GLIBCXX_ASSERTIONS: turn the empty-string front() call into a hard abort
# instead of silent undefined behaviour.
$CXX -std=c++11 -g -O1 -D_GLIBCXX_ASSERTIONS \
     -Ilibelfin -Ilibelfin/elf -Ilibelfin/dwarf \
     repro.cc $SOURCES -o repro

echo
echo "== ./repro $FIXTURE =="
exec ./repro "$FIXTURE"