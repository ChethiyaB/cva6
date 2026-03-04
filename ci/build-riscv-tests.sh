#!/bin/bash
set -e
set -x
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION="eeacd5507db7a0f50ca8c4f27aff220fcbb60bdf"

mkdir -p $ROOT/tmp
cd $ROOT/tmp

if [ -z ${NUM_JOBS} ]; then
    NUM_JOBS=1
fi

# Clone only if riscv-tests is missing or not a git repo (e.g. empty dirs from mkdir)
if [ ! -d $ROOT/tmp/riscv-tests/.git ]; then
    rm -rf $ROOT/tmp/riscv-tests
    git clone https://github.com/riscv/riscv-tests.git $ROOT/tmp/riscv-tests
fi
cd riscv-tests
git checkout $VERSION
git submodule update --init --recursive
autoconf

# Fix legacy CSR names for current toolchains (same CSRs, renamed in priv spec):
#   sptbr -> satp,  sbadaddr -> stval,  mbadaddr -> mtval
for dir in isa env benchmarks; do
  [ -d "$dir" ] || continue
  for f in $(find "$dir" -type f 2>/dev/null); do
    grep -qE 'sptbr|sbadaddr|mbadaddr' "$f" 2>/dev/null || continue
    sed -i.bak -e 's/sptbr/satp/g' -e 's/sbadaddr/stval/g' -e 's/mbadaddr/mtval/g' "$f"
    rm -f "${f}.bak"
  done
done

mkdir -p build
cd build
../configure --prefix=$ROOT/tmp/riscv-tests/build

# Build only 64-bit ISA tests (CVA6 default target is rv64; skip rv32 to avoid
# "reference is not a tree" / missing rv32 toolchain or multilib issues)
sed -i.bak '/include.*rv32.*Makefrag/s/^/# /' ../isa/Makefile

make isa        -j${NUM_JOBS} > /dev/null

# Allow legacy benchmarks (e.g. dhrystone K&R C) to build with modern GCC
sed -i.bak 's/-fno-tree-loop-distribute-patterns/-fno-tree-loop-distribute-patterns -Wno-implicit-int -Wno-implicit-function-declaration/' ../benchmarks/Makefile
rm -f ../benchmarks/Makefile.bak

make benchmarks -j${NUM_JOBS} > /dev/null
make install
