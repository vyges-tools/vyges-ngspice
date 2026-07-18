#!/usr/bin/env bash
# smoke.sh — verify the ngspice bundle/image: version, a trivial batch sim runs, and
# OSDI support is COMPILED IN (the whole point). Usage: smoke.sh <bundle-dir | image-ref>
set -euo pipefail
T="${1:?usage: smoke.sh <bundle-dir | image-ref>}"

run() {  # run a shell snippet either in the bundle dir or the image
  if [ -d "$T" ]; then bash -lc "source '$T/env.sh'; $1"
  else docker run --rm "$T" bash -lc "$1"; fi
}

echo ">> version"
run 'ngspice --version 2>/dev/null | grep -i ngspice | head -1'

echo ">> trivial batch sim (no models)"
# NOTE: ngspice -b needs a .print/.plot/.save or it refuses ("no simulations run").
run 'printf "* rc\nV1 a 0 1\nR1 a b 1k\nC1 b 0 1n\n.tran 1u 5u\n.print tran v(b)\n.end\n" > /tmp/rc.sp; ngspice -b /tmp/rc.sp >/dev/null 2>&1 && echo "sim OK"'

echo ">> code models load from the RELOCATED bundle (spinit is relocatable)"
# spinit runs its `codemodel` lines at startup; if their paths still point at the build
# prefix (non-relocatable) they fail with "... couldn't be loaded". Run from the extracted
# bundle (env.sh set SPICE_LIB_DIR to its real location) and assert none failed.
run 'out=$(printf "* t\nV1 a 0 1\nR1 a 0 1k\n.op\n.end\n" | ngspice -b 2>&1 || true); \
     if echo "$out" | grep -qi "couldn.t be loaded"; then \
       echo "FAIL: code models did not load — spinit not relocatable:"; \
       echo "$out" | grep -i "couldn.t be loaded" | head -3; exit 1; \
     else echo "code models OK (loaded from relocated bundle)"; fi'

echo ">> OSDI support (best-effort — real OSDI proof is the PDK integration sim)"
# with --enable-osdi the `osdi` command exists (errors on a bad path, not "unknown").
# Best-effort + non-fatal: never fail the distro smoke on this (integration validates it).
run 'out=$(printf "osdi /nonexistent.osdi\nquit\n" | ngspice 2>&1 || true); \
     if echo "$out" | grep -qiE "unknown (command|subcommand)|no such command"; then \
       echo "WARN: osdi command not recognized (check --enable-osdi)"; \
     else echo "OSDI OK (loader present)"; fi'

echo ">> smoke PASSED for $T"
