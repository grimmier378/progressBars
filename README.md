Progress Bars (MacroQuest Lua + ImGui + ImAnim)

Reusable animated horizontal and vertical progress bars for MacroQuest Lua.

This project separates the reusable bar logic (progressBars.lua) from the demo/showcase implementation (init.lua) so you can drop the bar system into other scripts easily.

🎯 Intent

The goal of this project is:

✅ Provide a drop-in progress bar module

✅ Support both horizontal and vertical bars

✅ Include animation via ImAnim

✅ Provide optional visual effects (gradient, shimmer, glow, ticks, border, overlays)

✅ Allow customization per-bar

✅ Showcase functionality in a clean demo file

If you just want the functionality, you only need:

progressBars.lua

Everything else is demonstration.

📁 File Structure

progressBars.lua -- Reusable module (drop into any script)

init.lua -- Demo / showcase implementation

/images -- Optional overlay textures

🚀 Quick Start (Drop-In Usage)
1️⃣ Require the module

```
local StatusBar = require('progressBars')
```

2️⃣ Draw a horizontal bar

```
StatusBar.DrawProgress(
	"HealthBar",
	mq.TLO.Me.PctHPs(),
	ImVec4(0.5, 0.1, 0.9, 1.0),  -- Low color
	ImVec4(1.0, 0.1, 0.1, 1.0),  -- High color
	{
		height = 18,
		showText = true,
		shimmer = true,
		fillGradient = true,
	}
)
```

3️⃣ Draw a vertical bar

```
StatusBar.DrawProgressVert(
	"ManaBar",
	mq.TLO.Me.PctMana(),
	ImVec4(0.2, 0.2, 0.6, 1.0),
	ImVec4(0.2, 0.8, 1.0, 1.0),
	{
		width = 25,
		height = 120,
		fillGradient = true,
		fillGradientDir = "tb",
		shimmer = true,
	}
)
```

That’s it.

✨ Features
✔ Animated Tweening

Smooth progress transitions via ImAnim.TweenFloat

Configurable easing duration (tweenSeconds)

✔ Gradient Fill

Static or dynamic mode

Direction:

"lr" (left → right)

"tb" (top → bottom)

✔ Shimmer Effect

Optional animated shimmer

Can follow fill direction (shimmerFollows)

Adjustable speed and width

✔ Glow Edge

Subtle highlight at fill boundary

Clamped so it does not extend past fill

✔ Tick Marks

Custom spacing (e.g. every 5%, 10%, etc.)

Adjustable thickness and opacity

✔ Border Options

Static color

Optional con-color tracking

Adjustable thickness

✔ Overlay Support (Mask / Styling Layer)

Supports PNG overlays:

Static overlay (full mask shown regardless of fill)

Clipped overlay (only visible over filled portion)

Useful for:

Dragon cutout masks

Decorative glass effects

Textured bar styling

🖼 Overlay Options

```
overlayOn = true,
overlay = overlayTexture,
overlayStatic = true, -- true = full overlay always shown
overlayPadding = 0,
overlayTint = IM_COL32(255,255,255,255),
Modes
Mode	Behavior
overlayStatic = true	Draw overlay full size (like a lens)
overlayStatic = false	Clip overlay to fill width
```

⚙ Configuration Options

Common options:

```
{
	height = 20,
	width = 0,
	padEnd = 10,
	rounding = 6,

	showText = true,
	textFmt = "%.1f%%",

	fillGradient = true,
	fillGradientMode = "dynamic", -- or "static"
	fillGradientDir = "lr",       -- or "tb"

	shimmer = true,
	shimmerFollows = true,
	shimmerSpeed = 0.5,
	shimmerWidth = 60,

	glow = true,

	showTicks = true,
	tickEvery = 0.1,
	tickThickness = 1.0,

	border = true,
	borderThickness = 2,
	borderColor = ImVec4(1,1,1,1),

	tweenSeconds = 0.35,
}
```

📐 Horizontal vs Vertical Behavior

Feature Horizontal Vertical

Fill Direction Left → Right Bottom → Top

Gradient Default "lr" "tb"

Glow Direction Right edge Top edge

Ticks Vertical lines Horizontal lines

🧠 Design Notes

Uses mq.gettime() for shimmer timing.

Each bar keeps its own state internally.

Tweening is ID-based, so labels must be unique.

Overlay textures use mq.CreateTexture().

You can:

Drop progressBars.lua your scripts

init.lua is purely for demonstration and testing.

🔮 Future Improvements

Optional vertical text rotation (requires ImGui transform bindings)

Rounded multi-color gradient fill support

Optional masked glow blending

Config serialization helper
