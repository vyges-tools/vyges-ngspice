# vyges-ngspice

A Vyges-controlled, versioned, **reproducible distribution of headless, OSDI-enabled
ngspice** — the analog simulator built `--without-x` (no plot GUI, no X deps) and
`--enable-osdi` so it can run **modern PDK models** (e.g. IHP sg13's PSP103 OSDI /
OpenVAF models). This is exactly what stock `apt` ngspice can't do: distro packages
are usually too old for OSDI, so a batch/CI/agentic analog flow needs a from-source build.

- **Rebuild, never fork or vendor.** We build ngspice at a pinned release tag — this
  repo holds only the *build recipe* (CI clones upstream at build time). No patches.
- **Headless.** `--without-x` → a clean batch simulator (`ngspice -b`), no X server.
- **Multi-arch.** Native builds for **linux/amd64 + linux/arm64**.
- **Binary-first.** Relocatable `tar.gz` is the product; the container wraps the same bytes.
- **Images:** `ghcr.io/vyges-tools/vyges-ngspice` · **Tarballs:** GitHub Releases.

## Use it

```sh
# tarball (relocatable):
tar xzf vyges-ngspice-46-g<short>-linux-x86_64.tar.gz
source vyges-ngspice-46-g<short>/env.sh    # PATH + LD_LIBRARY_PATH + SPICE_LIB_DIR
ngspice -b my.spice

# container:
docker run --rm ghcr.io/vyges-tools/vyges-ngspice:latest ngspice --version
```

**Running PDK sims (OSDI):** ngspice loads the PDK's OSDI models via the PDK's
`.spiceinit` — set `PDK`, `PDK_ROOT`, and `SPICE_USERINIT_DIR=<pdk>/libs.tech/ngspice`,
and mount the PDK. The OSDI models themselves (`psp103.osdi`, …) are PDK-side, compiled
by OpenVAF; this image ships the OSDI-*capable* ngspice.

## How it's built

`scripts/build-bundle.sh` configures + builds ngspice headless at the pinned ref and
assembles the relocatable bundle (bin + libs + `share/ngspice` spinit/codemodels +
`env.sh`). `Dockerfile.runtime` wraps the same bundle into a slim image.
Workflows: `release.yml` (multi-arch build → tarballs + image), `multiarch-check.yml`
(verify both arches without publishing).

## Cut a release / bump the pin

Edit **`upstream.yaml`** (`ref`) — the source of truth — then run the `release`
workflow with a `version`.

## Licensing

Repository tooling (Dockerfile, scripts, workflows) is **Apache-2.0** (`LICENSE`).
The built artifact is **ngspice** (modified-BSD core; some XSPICE code models GPL) —
each bundle ships ngspice's own license as `LICENSE.ngspice`.
