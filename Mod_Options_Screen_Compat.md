# Gen1BetterMenus — Mod Options Screen Compatibility

Gen1BetterMenus supports third-party mod options and settings screens through a simple opt-in marker:

```lua
isModOptions = true
```

Adding this marker tells Gen1BetterMenus that the screen is an options-style interface, allowing it to apply the correct widescreen layout behavior without depending on your mod name or a specific `screenId`.

## Recommended usage

If your options screen is defined as its own screen module or factory table, add the marker directly to that table:

```lua
local OptionsScreen = {
  isModOptions = true,
}

function OptionsScreen.new(game)
  local self = {
    game = game,
    rows = {},
    index = 1,
    scroll = 0,
  }

  return self
end

return OptionsScreen
```

That is the preferred approach when your screen is registered through Gen1Recomp's screen system.

## Manually-created screens

If your mod creates a screen table directly and pushes it onto the state stack itself, add the marker directly to that screen table:

```lua
local screen = {
  game = game,
  isModOptions = true,
  rows = rows,
  index = 1,
  scroll = 0,
}

game.stack:push(screen)
```

The important part is simply that the options screen being displayed contains:

```lua
isModOptions = true
```

## Why this marker exists

Without an explicit marker, UI mods have to infer whether a screen is an options screen from things such as its `screenId`:

```lua
screenId == "MyModOptions"
```

or naming conventions:

```lua
screenId:match("Options$")
screenId:match("Settings$")
```

That works, but it creates unnecessary coupling between unrelated mods.

An explicit marker provides a much cleaner contract:

```lua
isModOptions = true
```

Your mod identifies the purpose of its own screen, and compatible UI mods can respond appropriately.

This avoids:

- Hardcoded mod IDs

- Hardcoded screen names

- Per-mod compatibility patches

- Breakage when screens are renamed

- UI mods needing prior knowledge of every options mod

## No Gen1BetterMenus dependency is required

Your mod does not need to detect, require, or reference Gen1BetterMenus.

Do not do this:

```lua
require("Gen1BetterMenus")
```

Simply mark your options screen:

```lua
isModOptions = true
```

If Gen1BetterMenus is installed, it can recognize the marker.

If Gen1BetterMenus is not installed, the extra Lua field has no effect.

This keeps compatibility optional and avoids creating a dependency between the two mods.

## Updating an existing screen

If your current screen looks like this:

```lua
local screen = {
  game = game,
  rows = rows,
  index = 1,
  scroll = 0,
  isOpaque = true,
}
```

add one line:

```lua
local screen = {
  game = game,
  rows = rows,
  index = 1,
  scroll = 0,
  isOpaque = true,
  isModOptions = true,
}
```

That's all that is required for detection.

## Screen module example

Before:

```lua
local OptionsScreen = {}

function OptionsScreen.new(game)
  return {
    game = game,
    rows = buildRows(game),
    index = 1,
    scroll = 0,
  }
end

return OptionsScreen
```

After:

```lua
local OptionsScreen = {
  isModOptions = true,
}

function OptionsScreen.new(game)
  return {
    game = game,
    rows = buildRows(game),
    index = 1,
    scroll = 0,
  }
end

return OptionsScreen
```

## Direct screen example

Before:

```lua
local screen = {
  game = game,
  rows = rows,
  index = 1,
  scroll = 0,
}

game.stack:push(screen)
```

After:

```lua
local screen = {
  game = game,
  isModOptions = true,
  rows = rows,
  index = 1,
  scroll = 0,
}

game.stack:push(screen)
```

## Compatibility behavior

Gen1BetterMenus supports the explicit `isModOptions` marker while retaining legacy detection for older mods whose screen IDs end in names such as:

```text
Options
Settings
```

The explicit marker is preferred because it is predictable, self-documenting, and does not depend on naming conventions.

## If your screen still has an issue

If your options screen already includes:

```lua
isModOptions = true
```

and it still renders incorrectly with Gen1BetterMenus, please report the issue with either:

- A link to the mod repository

- The relevant options-screen code

- A screenshot showing the layout problem

At that point it is likely a genuine compatibility issue rather than a screen-detection issue.



Thanks for adding the marker and helping keep Gen1Recomp mods interoperable. 💚
