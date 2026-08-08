# Contributing

## Contributions and licensing

Theme contributions are expected to be shared under the same
[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) license as this
project. Please only contribute work you created or have permission to share,
and include the name or link you would like used for credit. Contributions will
be attributed where appropriate.

## Theme structure

Follow the existing conventions. The full layout supports multiple variants and shared assets:

```text
themes/<theme>/
├── README.md
├── assets/
│   └── boards/                  # optional boards shared by every variant
└── variants/
    └── <variant>/
        ├── preview.webp
        ├── assets/
        │   ├── boards/          # only when boards differ by variant
        │   └── stones/
        │       ├── black-01.png
        │       └── white-01.png
        └── sabaki/
            ├── package.json
            ├── styles.css
            └── stone-variants.css
```

For a theme with only one configuration, omit `variants/<variant>/` and place
its `preview.webp`, `assets/`, and `sabaki/` directly under `themes/<theme>/`.
Board sizes such as `9x9`, `13x13`, and `19x19` belong together and are not
variants.

Create variants for deliberately different boards, stones, lighting, or
palettes. Treat every variant as a first-class configuration for Sabaki, OGS,
and GoPanda2/Pandanet.

Place assets at the nearest directory shared by every configuration that uses
them. Shared boards belong in `themes/<theme>/assets/boards/`; differing boards
and stones belong with their variant. Do not duplicate assets.

The `sabaki/` directory contains checked-in metadata and CSS, not duplicated
assets.

## Documentation and previews

Use one `README.md` per theme, even if it has variants. For variants, include an anchor-linked table and
separate Sabaki, OGS, and GoPanda2/Pandanet instructions for each variant. Use
direct rolling-release ASAR links and collapsible blocks for long OGS JSON.

## Building a Sabaki theme

Pass the checked-in Sabaki files, boards, and stones explicitly:

```bash
scripts/pack-sabaki.sh \
  --sabaki themes/starfield/variants/red-yellow/sabaki \
  --boards themes/starfield/assets/boards \
  --stones themes/starfield/variants/red-yellow/assets/stones
```

The archive name comes from `sabaki/package.json`; output defaults to
`dist/<package-name>.asar`. Use `--output FILE` to override it. The builder
packages existing CSS unchanged and does not generate theme files. Do not add
theme-specific packing scripts.

The ignored `dist/` directory contains generated archives. After testing one in
its client, publish it as an asset of the rolling GitHub release.
