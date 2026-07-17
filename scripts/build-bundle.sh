#!/usr/bin/env bash
# build-bundle.sh — build headless (--without-x) OSDI-enabled ngspice at the pinned
# ref and assemble a RELOCATABLE tar.gz into $OUT_DIR. THE TAR.GZ IS THE PRODUCT.
#
# Env: NG_REF (req, e.g. ngspice-46), VERSION (default dev), OUT_DIR (default /out),
#      NG_TREE (default /tmp/ngspice — a clone of the ngspice source).
set -euo pipefail

NG_REF="${NG_REF:?set NG_REF (e.g. ngspice-46)}"
VERSION="${VERSION:-dev}"
OUT_DIR="${OUT_DIR:-/out}"
NG_TREE="${NG_TREE:-/tmp/ngspice}"
PREFIX="/tmp/ngspice-install"
mkdir -p "$OUT_DIR"

cd "$NG_TREE"
git checkout -q "$NG_REF"
SHORT="$(git rev-parse --short=12 HEAD)"

echo "== configure + build (headless, OSDI) =="
./autogen.sh
./configure --prefix="$PREFIX" \
  --enable-osdi --enable-xspice --without-x --with-readline=yes --disable-debug
make -j"$(nproc)"
make install

# --- assemble the relocatable bundle ---
NAME="vyges-ngspice-${VERSION}-g${SHORT}"
B="$OUT_DIR/$NAME"
rm -rf "$B"; mkdir -p "$B"
cp -a "$PREFIX/." "$B/"

# ship ngspice's own license alongside the binary
for L in COPYING DEVNOTES.md; do [ -f "$NG_TREE/$L" ] && cp "$NG_TREE/$L" "$B/LICENSE.ngspice" && break; done

# env.sh makes the bundle relocatable: PATH + its libs + SPICE_LIB_DIR (spinit + codemodels)
cat > "$B/env.sh" <<'EOS'
D="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export PATH="$D/bin:$PATH"
export LD_LIBRARY_PATH="$D/lib:${LD_LIBRARY_PATH:-}"
export SPICE_LIB_DIR="$D/share/ngspice"
EOS

if [ -x "${SCRIPTS_DIR:-$(dirname "$0")}/provenance.sh" ]; then
  NG_REF="$NG_REF" VERSION="$VERSION" NG_TREE="$NG_TREE" \
    "${SCRIPTS_DIR:-$(dirname "$0")}/provenance.sh" > "$B/manifest.json" || true
fi

# MCP-friendly tool descriptor (the container/bundle analog of a loom engine's
# --describe) so the vyges resolve/MCP layer can discover + invoke this tool.
cat > "$B/vyges-tool.json" <<TOOLJSON
{
  "schema": "vyges-tool-descriptor/1.0",
  "tool": "ngspice",
  "version": "${VERSION}",
  "kind": "backing-tool",
  "headless": true,
  "provides": ["spice-sim", "transient", "dc", "ac", "osdi-models"],
  "invoke": { "cli": "ngspice", "batch_flag": "-b" },
  "env": { "required": [], "optional": ["PDK", "PDK_ROOT", "SPICE_USERINIT_DIR", "SPICE_LIB_DIR"] },
  "license": "BSD-3-Clause",
  "upstream_ref": "${NG_REF}",
  "upstream_commit": "${SHORT}"
}
TOOLJSON

echo "== tarball (THE PRODUCT) =="
ARCH="$(uname -m)"                      # x86_64 or aarch64 — not hardcoded
TARBALL="${NAME}-linux-${ARCH}.tar.gz"
tar -C "$OUT_DIR" -czf "$OUT_DIR/${TARBALL}" "$NAME"
du -sh "$B" "$OUT_DIR/${TARBALL}"
echo "BUILD_BUNDLE_OK short=$SHORT arch=$ARCH tarball=${TARBALL}"
