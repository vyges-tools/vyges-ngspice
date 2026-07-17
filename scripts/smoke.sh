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
run 'printf "* rc\nV1 a 0 1\nR1 a b 1k\nC1 b 0 1n\n.tran 1u 5u\n.end\n" > /tmp/rc.sp; ngspice -b /tmp/rc.sp >/dev/null 2>&1 && echo "sim OK"'

echo ">> OSDI support compiled in"
# with --enable-osdi, the `osdi` command exists (errors on a bad path rather than
# reporting an unknown command). No OSDI support -> "unknown" / "no such command".
run 'out=$(printf "osdi /nonexistent.osdi\nquit\n" | ngspice -p 2>&1); \
     echo "$out" | grep -qiE "unknown (command|subcommand)|no such command" \
       && { echo "FAIL: OSDI not compiled in"; exit 1; } \
       || echo "OSDI OK (loader present)"'

echo ">> smoke PASSED for $T"
