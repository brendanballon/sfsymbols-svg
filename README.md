# ⌘ sfsymbols-svg
A compilation of Apple's SF Symbols in `.svg` format.

## Current coverage
This repository now includes exports generated from the latest SF Symbols release line (SF Symbols 7), using the symbol metadata bundled in the installed app.

## How symbols are generated
The original README referenced a fork of a deprecated CLI that is no longer available. This repo now includes a local generator script:

- `/Users/brendanballon/Documents/sfsymbols-svg/scripts/export_sf_symbols.swift`

The script reads these files from the installed SF Symbols app bundle:

- `symbol_names.txt`
- `symbol_chars.txt`
- `SF-Pro.ttf` (fallback: `SFSymbolsFallback.ttf`)

and writes one SVG per symbol to `/Users/brendanballon/Documents/sfsymbols-svg/symbols`.

## Regenerate symbols
```sh
swift scripts/export_sf_symbols.swift
```

Optional flags:

- `--app-path <path>`: alternate app bundle path
- `--output <path>`: alternate output directory
- `--size small|medium|large`: glyph size variant (default: `large`)
- `--no-clean`: keep existing files in output directory
