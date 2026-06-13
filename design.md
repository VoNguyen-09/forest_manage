---
version: alpha
name: Starbucks
description: Four-tier green. Warm cream canvas. Full-pill buttons.
colors:
  primary: "#1E3932"
  secondary: "#6F7E72"
  tertiary: "#006241"
  neutral: "#F2F0EB"
  surface: "#FBF8F0"
  on-primary: "#FBF8F0"
typography:
  display:
    fontFamily: Inter
    fontSize: 4.5rem
    fontWeight: 700
    letterSpacing: "-0.025em"
  h1:
    fontFamily: Inter
    fontSize: 2.3rem
    fontWeight: 600
  body:
    fontFamily: Inter
    fontSize: 1rem
    lineHeight: 1.6
  label:
    fontFamily: Inter
    fontSize: 0.78rem
    fontWeight: 600
    letterSpacing: "0.04em"
rounded:
  sm: 100px
  md: 100px
  lg: 100px
spacing:
  sm: 8px
  md: 16px
  lg: 32px
components:
  button-primary:
    backgroundColor: "{colors.tertiary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
    padding: 12px 20px
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    rounded: "{rounded.lg}"
    padding: 24px
---
## Overview

Starbucks: signature green on warm cream, full-pill interactive elements, generous white space, friendly sans.

## Colors

The palette is built around high-contrast neutrals and a single accent that drives interaction.

- **Primary (`#1E3932`):** Headlines and core text.
- **Secondary (`#6F7E72`):** Borders, captions, and metadata.
- **Tertiary (`#006241`):** The sole driver for interaction. Reserve it.
- **Neutral (`#F2F0EB`):** The page foundation.

## Typography

- **display:** Inter 4.5rem
- **h1:** Inter 2.3rem
- **body:** Inter 1rem
- **label:** Inter 0.78rem

## Do's and Don'ts

- **Do** use Tertiary for exactly one action per screen.
- **Do** let Neutral carry the composition — negative space is a feature.
- **Don't** introduce gradients. This system is flat on purpose.
- **Don't** mix Tertiary with alternate accents; the single-accent rule is load-bearing.
