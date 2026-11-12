/**
 * Jolom brand palette (source of truth for docs / JS).
 * CSS runtime tokens live in `src/app/globals.css`.
 *
 * Each entry: light | dark
 */
export const brandColors = {
  bondi: { light: "#0095B6", dark: "#56D6EC" },
  primaryButton: { light: "#006A7C", dark: "#56D6EC" },
  onPrimary: { light: "#FFFFFF", dark: "#00363F" },
  bondiSoft: { light: "#A9EDFA", dark: "#00505F" },
  amber: { light: "#8B5000", dark: "#FFB95F" },
  amberSoft: { light: "#FFDDB3", dark: "#673B00" },
  celadon: { light: "#3E6B50", dark: "#A4D3B4" },
  celadonSoft: { light: "#BFECCF", dark: "#285139" },
  background: { light: "#F7FAFB", dark: "#0F1416" },
  card: { light: "#FFFFFF", dark: "#171C1E" },
  secondary: { light: "#E3F0F2", dark: "#253033" },
  /** Derived until brand table for text/border/error is provided */
  foreground: { light: "#0F1416", dark: "#F7FAFB" },
  mutedForeground: { light: "#253033", dark: "#E3F0F2" },
  border: { light: "#E3F0F2", dark: "#253033" },
  destructive: { light: "#BA1A1A", dark: "#FFB4AB" },
} as const;

export type BrandColorName = keyof typeof brandColors;
