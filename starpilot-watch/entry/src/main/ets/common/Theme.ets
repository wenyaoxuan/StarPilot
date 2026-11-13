export class Palette {
  bg: string = '#000000';
  fg: string = '#FFFFFF';
  dim: string = '#8E8E93';
  accent: string = '#FF453A';
  card: string = '#141414';
  line: string = '#2C2C2E';

  constructor(red: boolean) {
    if (red) {
      this.bg = '#000000';
      this.fg = '#FF5A4E';
      this.dim = '#8C1D18';
      this.accent = '#FF3B30';
      this.card = '#140000';
      this.line = '#3A0A08';
    }
  }
}

export function palette(red: boolean): Palette {
  return new Palette(red);
}
