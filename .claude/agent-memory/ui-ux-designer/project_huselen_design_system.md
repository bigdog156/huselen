---
name: Huselen Design System Foundation
description: Core design tokens, component library, and role-based color mapping for the Huselen Vietnamese fitness/PT management iOS app
type: project
---

Huselen is a Vietnamese-language iOS fitness/PT management app built with SwiftUI (iOS 17+).

**Design system lives in two files:**
- `Views/Theme/FitColors.swift` — flat Color extensions (fitGreen, fitCard, fitTextPrimary, etc.)
- `Views/Theme/Theme.swift` — structured enum with Colors, Radius, Fonts + reusable modifiers (CuteCardModifier, CuteButtonStyle, CuteBadge, CuteIconCircle, CuteStatCard, CuteTextFieldModifier, CuteRowModifier)

**Role-based accent colors:**
- Client: fitGreen (#22C55E)
- Trainer (gym-employed): softOrange
- Trainer (freelance): softOrange (same)
- Admin/Owner: warmYellow

**Design language:** "Cute" / Locket-inspired — rounded font design (.rounded), soft shadows (0.06 opacity, radius 12), continuous corner radius (14/20/26), gradient-filled buttons with colored shadow, capsule badges with 12% opacity fill.

**Why:** The app serves Vietnamese gym owners, PT trainers, and clients. Three distinct tab views exist per role. Screens should avoid default List styling in favor of custom cards where visual hierarchy matters.

**How to apply:** Always use Theme.Fonts (rounded design), Theme.Radius, and the CuteCard/CuteButton/CuteBadge components. Match accent color to the user role viewing the screen. Use `.gradient` on fills for primary action buttons.
