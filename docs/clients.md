# Client notes

## OGS

OGS custom themes load board and stone images from public URLs. The theme pages
in this repository provide complete JSON configurations to copy into the OGS
theme importer.

The URLs point to canonical files under each theme's `assets/` directory served
by the Goban Decals GitHub Pages site. Multiple stone URLs allow OGS to vary the
appearance of stones across the board.

## GoPanda2/Pandanet

[`pandanet-tweaker`](https://github.com/lykahb/pandanet-tweaker) can install a
theme from the canonical local assets. Each theme README provides a complete
command using paths relative to that theme directory.

The command supplies a gridless fallback board, exact baked-grid boards for
9×9, 13×13, and 19×19, all stone variants, and the palette needed for markers
and coordinates.

## Sabaki

Self-contained Sabaki `.asar` packages are published under the repository's
[GitHub Releases](https://github.com/lykahb/goban-decals/releases). Download a
package and install it through Sabaki's theme preferences.

The `sabaki/` directory under each theme contains the client-specific package
metadata and CSS for reference. It deliberately does not duplicate the
canonical board and stone files. Published archives contain their own copies
of every runtime asset.
