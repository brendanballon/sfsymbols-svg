# ⌘ sfsymbols-svg
A compilation of Apple's SF Symbols in `.svg` format.

## Current coverage
This repository includes all 6,404 symbols from the latest SF Symbols release (SF Symbols 7 / app version 26.x), exported using the symbol metadata bundled in the installed SF Symbols app.

## How symbols are generated
The original export relied on a fork of a now-deprecated CLI. This repo now includes a local generator script, `scripts/export_sf_symbols.swift`, which reads these files from the installed SF Symbols app bundle:

- `symbol_names.txt`
- `symbol_chars.txt`
- `SF-Pro.ttf` (fallback: `SFSymbolsFallback.ttf`)

and writes one SVG per symbol to `symbols/`.

## Regenerate symbols
```sh
swift scripts/export_sf_symbols.swift
```

Optional flags:

- `--app-path <path>`: alternate app bundle path
- `--output <path>`: alternate output directory
- `--size small|medium|large`: glyph size variant (default: `large`)
- `--no-clean`: keep existing files in output directory
