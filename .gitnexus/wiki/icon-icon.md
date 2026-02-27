# Icon.icon

<think>
Let me analyze this module. Based on the provided information, I need to understand what this module does and document it appropriately.

Looking at the icon.json file, this appears to be a configuration file for an icon in a UI system. Let me break down the components:

1. **fill** - Contains an automatic gradient with extended-sRGB color values
2. **groups** - Contains layer information (an image called "codexbar.png")
3. **supported-platforms** - Specifies which platforms support this icon (watchOS for circles, shared for squares)

The module is called "Icon.icon" and it seems to be a configuration/specification for an icon rather than executable code. The call graph shows no internal or external calls, and no execution flows detected.

This is essentially a JSON configuration that defines:
- The visual appearance of an icon (gradient fill)
- The image layers that make up the icon
- Shadow and translucency effects
- Platform compatibility

Let me write comprehensive documentation for this module, treating it as the configuration specification it is.
</think>

# Icon.icon Module Documentation

## Overview

The **Icon.icon** module defines the visual specification, rendering behavior, and platform compatibility for a single icon asset in the application. This module is a JSON-based configuration that describes how an icon should appear and where it can be used.

## Purpose

This module serves as a declarative definition for icon rendering across the application's UI layer. It controls:

- **Visual appearance** — Fill colors and gradients
- **Layer composition** — Image assets that compose the icon
- **Visual effects** — Shadows and translucency
- **Platform targeting** — Where the icon can be displayed

## Configuration Structure

```json
{
  "fill": { ... },
  "groups": [ ... ],
  "supported-platforms": { ... }
}
```

---

## Key Components

### 1. Fill (Color Specification)

```json
"fill": {
  "automatic-gradient": "extended-srgb:0.00000,0.53333,1.00000,1.00000"
}
```

The `fill` property defines the icon's primary color as an automatic gradient using the **extended-sRGB** color space.

| Value | Component | Interpretation |
|-------|-----------|----------------|
| `0.00000` | R | Red channel (0%) |
| `0.53333` | G | Green channel (~53%) |
| `1.00000` | B | Blue channel (100%) |
| `1.00000` | A | Alpha/opacity (fully opaque) |

This produces a **blue** gradient with no red, moderate green, and full blue — resulting in a vivid cyan-to-blue appearance.

> **Note:** The "automatic-gradient" designation suggests the rendering system dynamically adjusts the gradient based on context (e.g., light/dark mode, user preferences) while using these values as the baseline.

---

### 2. Groups (Layer Composition)

```json
"groups": [
  {
    "layers": [
      {
        "image-name": "codexbar.png",
        "name": "codexbar",
        "position": {
          "scale": 1.4,
          "translation-in-points": [0, 0]
        }
      }
    ],
    "shadow": {
      "kind": "neutral",
      "opacity": 0.5
    },
    "translucency": {
      "enabled": true,
      "value": 0.5
    }
  }
]
```

The `groups` array contains one or more render groups, each with:

#### Layers

| Property | Value | Description |
|----------|-------|-------------|
| `image-name` | `"codexbar.png"` | The source image asset |
| `name` | `"codexbar"` | Internal identifier for the layer |
| `position.scale` | `1.4` | Scale factor (140% of base size) |
| `position.translation-in-points` | `[0, 0]` | No offset from origin |

#### Shadow Configuration

```json
"shadow": {
  "kind": "neutral",
  "opacity": 0.5
}
```

- **kind**: `"neutral"` — Uses a neutral gray shadow color that adapts to context
- **opacity**: `0.5` — 50% opacity, creating a moderate shadow

#### Translucency

```json
"translucency": {
  "enabled": true,
  "value": 0.5
}
```

- **enabled**: `true` — Translucency effect is active
- **value**: `0.5` — 50% translucency, allowing partial visibility of content behind the icon

---

### 3. Supported Platforms

```json
"supported-platforms": {
  "circles": ["watchOS"],
  "squares": "shared"
}
```

The `supported-platforms` property defines where this icon can be rendered based on shape context:

| Shape | Platform Support | Meaning |
|-------|-----------------|---------|
| `circles` | `["watchOS"]` | Only usable in circular icon contexts on watchOS |
| `squares` | `"shared"` | Available across all platforms in square/icon-square contexts |

> **Implication:** This icon is specifically optimized for Apple Watch interfaces (circular) while maintaining broader availability for standard square icon slots.

---

## Rendering Pipeline

Since this module contains no executable code, the actual rendering happens in a separate icon rendering system that consumes this configuration. Based on the structure, the expected pipeline is:

```mermaid
flowchart LR
    A[JSON Config<br/>Icon.icon] --> B[Config Parser]
    B --> C[Asset Loader<br/>codexbar.png]
    C --> D[Layer Compositor]
    D --> E[Effect Processor<br/>Shadow + Translucency]
    E --> F[Gradient Applicator<br/>extended-sRGB]
    F --> G[Platform Filter<br/>watchOS / shared]
    G --> H[Final Icon<br/>Rendered]
```

---

## Usage Notes

1. **Asset dependency**: This icon requires `codexbar.png` to be present in the application's asset catalog. If the asset is missing, rendering will fail or fall back to a placeholder.

2. **Scale impact**: The `1.4` scale factor means this icon renders 40% larger than the base icon size. Ensure the source image has sufficient resolution to avoid pixelation at larger sizes.

3. **Effect performance**: Enabling both shadow (`opacity: 0.5`) and translucency (`value: 0.5`) may impact rendering performance on resource-constrained devices like Apple Watch. Test on actual hardware.

4. **Platform-specific behavior**: The `"watchOS"` restriction for circles suggests this icon may be part of a watch face or complication. The `"shared"` designation for squares indicates it's also used in the main iOS/iPadOS app.

---

## Related Modules

This module likely connects to:

- **Icon Rendering System** — Consumes this configuration to produce rendered icons
- **Asset Catalog** — Stores the `codexbar.png` resource
- **Platform Selection Logic** — Determines which icon configuration to use based on device and context

---

## File Reference

| File | Purpose |
|------|---------|
| `Icon.icon/icon.json` | This configuration file |
| `codexbar.png` | Source image asset (external dependency) |