import p5 from 'p5';
import { canvasSpec } from './generator.js';

export function createPosterSketch(mount, initialState) {
  let state = initialState;
  let instance;

  instance = new p5((p) => {
    p.setup = () => {
      const canvas = p.createCanvas(canvasSpec.width, canvasSpec.height);
      canvas.parent(mount);
      p.pixelDensity(1);
      p.noLoop();
    };

    p.draw = () => {
      drawPoster(p, state);
    };
  });

  return {
    update(nextState) {
      state = nextState;
      instance.redraw();
    },
    exportPng() {
      const filename = `poster-${state.controls.layout}-${state.controls.seed}`;
      instance.saveCanvas(instance.canvas, filename, 'png');
    },
  };
}

function drawPoster(p, state) {
  const { palette, controls } = state;

  p.clear();
  p.background(palette.background);
  drawPaperTexture(p, state);

  if (controls.layout === 'halo-grid') {
    drawHaloGrid(p, state);
  } else if (controls.layout === 'ribbon-type') {
    drawRibbonType(p, state);
  } else {
    drawMosaicField(p, state);
  }

  drawPosterFrame(p, state);
}

function drawHaloGrid(p, state) {
  const { palette, shapes, controls } = state;
  const centerX = canvasSpec.width / 2;
  const centerY = canvasSpec.height / 2;
  const orbitBase = 180 + controls.scale * 2.3;

  p.noFill();
  p.stroke(palette.ink);
  p.strokeWeight(2);
  p.drawingContext.setLineDash([7, 18]);
  for (let i = 0; i < 5; i += 1) {
    const diameter = orbitBase + i * (92 + controls.chaos * 0.7);
    p.ellipse(centerX, centerY, diameter, diameter * 1.18);
  }
  p.drawingContext.setLineDash([]);

  shapes.forEach((shape, index) => {
    const orbit = orbitBase * 0.42 + (index % 9) * (37 + controls.scale * 0.4);
    const angle = shape.x * p.TWO_PI + shape.drift * p.PI;
    const x = centerX + Math.cos(angle) * orbit;
    const y = centerY + Math.sin(angle) * orbit * 1.18;

    p.push();
    p.translate(x, y);
    p.rotate(angle + shape.rotation);
    drawGlyph(p, shape, palette);
    p.pop();
  });

  p.noStroke();
  p.fill(palette.ink);
  p.textAlign(p.CENTER, p.CENTER);
  p.textStyle(p.BOLD);
  p.textSize(92);
  p.text('SEED', centerX, centerY - 20);
  p.textSize(26);
  p.textStyle(p.NORMAL);
  p.text(state.controls.seed.toUpperCase(), centerX, centerY + 56);
}

function drawRibbonType(p, state) {
  const { palette, shapes, controls } = state;
  const rows = 8;
  const rowHeight = canvasSpec.height / rows;

  p.noStroke();
  shapes.slice(0, rows * 2).forEach((shape, index) => {
    const y = (index % rows) * rowHeight + shape.drift * 120;
    p.fill(withAlpha(p, shape.color, 0.72));
    p.rect(-120, y, canvasSpec.width + 240, rowHeight * (0.42 + shape.y * 0.62));
  });

  p.textAlign(p.LEFT, p.CENTER);
  p.textStyle(p.BOLD);
  p.textSize(164 + controls.scale * 0.55);
  p.fill(palette.ink);
  p.text('MAKE', 70, 410);
  p.text('WALL', 70, 610);
  p.text('PAPER', 70, 810);

  shapes.forEach((shape, index) => {
    const x = 90 + ((index * 173) % 900) + shape.drift * 180;
    const y = 118 + ((index * 89) % 1100);

    p.push();
    p.translate(x, y);
    p.rotate(shape.rotation);
    drawGlyph(p, shape, palette);
    p.pop();
  });

  p.fill(palette.background);
  p.rect(70, 1080, 600 + controls.density * 2.6, 16);
  p.fill(palette.ink);
  p.textStyle(p.NORMAL);
  p.textSize(30);
  p.text(state.signature.toUpperCase(), 70, 1140);
}

function drawMosaicField(p, state) {
  const { palette, shapes, controls } = state;
  const columns = 5 + Math.round(controls.density / 24);
  const rows = 7 + Math.round(controls.density / 28);
  const cellWidth = canvasSpec.width / columns;
  const cellHeight = canvasSpec.height / rows;

  p.noStroke();
  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < columns; col += 1) {
      const shape = shapes[(row * columns + col) % shapes.length];
      const x = col * cellWidth;
      const y = row * cellHeight;

      p.fill(withAlpha(p, shape.color, 0.22 + shape.alpha * 0.36));
      p.rect(x, y, cellWidth + 1, cellHeight + 1);

      p.push();
      p.translate(x + cellWidth / 2, y + cellHeight / 2);
      p.rotate(shape.rotation);
      drawGlyph(p, { ...shape, size: shape.size * 0.72 }, palette);
      p.pop();
    }
  }

  p.fill(withAlpha(p, palette.background, 0.78));
  p.rect(70, 92, canvasSpec.width - 140, 182);
  p.fill(palette.ink);
  p.textAlign(p.LEFT, p.TOP);
  p.textStyle(p.BOLD);
  p.textSize(74);
  p.text('MOSAIC FIELD', 100, 120);
  p.textStyle(p.NORMAL);
  p.textSize(26);
  p.text(state.signature.toUpperCase(), 104, 214);
}

function drawGlyph(p, shape, palette) {
  const size = shape.size;
  const alpha = 0.48 + shape.alpha * 0.5;

  p.stroke(withAlpha(p, palette.ink, Math.min(0.75, alpha)));
  p.strokeWeight(shape.weight);
  p.fill(withAlpha(p, shape.color, alpha));

  if (shape.variant === 0) {
    p.rectMode(p.CENTER);
    p.rect(0, 0, size, size * 0.62);
  } else if (shape.variant === 1) {
    p.ellipse(0, 0, size, size);
  } else if (shape.variant === 2) {
    p.triangle(-size * 0.48, size * 0.42, 0, -size * 0.48, size * 0.48, size * 0.42);
  } else if (shape.variant === 3) {
    p.line(-size * 0.5, 0, size * 0.5, 0);
    p.line(0, -size * 0.5, 0, size * 0.5);
  } else {
    p.noFill();
    p.arc(0, 0, size, size, 0, p.PI + p.HALF_PI);
  }
}

function drawPosterFrame(p, state) {
  const { palette } = state;

  p.noFill();
  p.stroke(palette.ink);
  p.strokeWeight(5);
  p.rect(44, 44, canvasSpec.width - 88, canvasSpec.height - 88);

  p.noStroke();
  p.fill(palette.ink);
  p.textAlign(p.LEFT, p.BOTTOM);
  p.textStyle(p.BOLD);
  p.textSize(22);
  p.text('POSTER WALLPAPER FACTORY', 58, canvasSpec.height - 58);
  p.textAlign(p.RIGHT, p.BOTTOM);
  p.text(state.controls.palette.toUpperCase(), canvasSpec.width - 58, canvasSpec.height - 58);
}

function drawPaperTexture(p, state) {
  state.shapes.slice(0, 70).forEach((shape) => {
    p.noStroke();
    p.fill(withAlpha(p, shape.color, 0.035));
    p.circle(shape.x * canvasSpec.width, shape.y * canvasSpec.height, 18 + shape.size * 0.18);
  });
}

function withAlpha(p, colorValue, alpha) {
  const color = p.color(colorValue);
  color.setAlpha(Math.round(alpha * 255));
  return color;
}
