# Poster Wallpaper Factory

A small p5.js MVP for generating posters and wallpapers with six reproducible controls:

- Seed
- Layout: Halo Grid, Ribbon Type, Mosaic Field
- Palette
- Density
- Scale
- Chaos

## Run

```bash
npm install
npm run dev
```

Open `http://127.0.0.1:5173/`.

## Verify

```bash
npm test
npm run build
npm audit
```

## Notes

- PNG export renders at `1080 x 1440`.
- The URL query string stores the full control state, so a copied link reproduces the same artwork.
- The implementation borrows the p5Catalyst idea of a creative-coding workbench with GUI controls and deterministic output, but keeps the MVP as a small Vite app.

## References

- p5Catalyst: https://github.com/multitude-amsterdam/p5Catalyst
- Web Interface Guidelines: https://github.com/vercel-labs/web-interface-guidelines
