# Gen1BetterMenus 🎮

**A faithful widescreen UI for Gen1Recomp.**

Gen1BetterMenus expands Pokémon Gen 1's original interface for widescreen displays while preserving the look, structure, and visual language of the original games.

The goal is not to redesign Gen 1 into a modern PC interface. It is to make widescreen Gen 1 feel like it was always supposed to look this way.

Menus remain recognizably Pokémon Red, Blue, and Yellow — just with the additional screen space properly used.

> 🖥️ **Requires `BATTLE HUD: EXTENDED` to be enabled in Gen1Recomp.**

## ✨ Features

- Native **304×144 widescreen UI layouts**
- Faithful Gen 1-style frames, typography, spacing, and menu structure
- Extended battle UI designed around Gen1Recomp's [`BATTLE HUD: EXTENDED`](https://github.com/bryanthaboi/gen1recomp/pull/1378)
- Widescreen title screen menus and Continue information
- Widescreen Options and Settings screens
- Expanded Party, Pokédex, Summary, inventory, and list menus
- Improved dialogue and choice-box layouts
- Widescreen Mod Manager interface
- Improved location banners
- Widescreen Link / Bois Club interface
- Stable overworld scaling when wide menus are opened
- Proper handling of widescreen UI palette zones
- Preservation of true-color battle graphics and semantic HP-bar colors
- Pokémon Yellow-specific title screen color handling
- Multiple selectable menu palettes
- Optional inverse palette mode

## 🎯 Design Philosophy

Gen1BetterMenus is intentionally **not a modern UI replacement**.

The project follows a simple rule:

**Extend Gen 1. Don't replace it.**

The original game's UI conventions are retained wherever possible — borders, text layout, cursor behavior, menu hierarchy, spacing, and overall composition.

Widescreen space is treated as additional room the original interface can naturally occupy rather than an excuse to redesign the game.

The target is a UI that feels less like a mod and more like a hypothetical official widescreen version of Pokémon Gen 1.

## 🎨 Palette Options

The menu palette can be changed independently through the Gen1Recomp Mod Manager.

Included palettes:

- Game Boy
- Black & White
- SoulSilver
- HeartGold
- FireRed
- LeafGreen
- Crystal
- Emerald

Each palette can also be displayed using the optional **Inverse** setting.

The default palette is **SoulSilver**.

## 📦 Installation

1. Download the latest `Gen1BetterMenus` ZIP.
2. Open **Gen1Recomp**.
3. Open the **Mod Manager**.
4. Import the ZIP.
5. Enable **Gen1BetterMenus**.
6. Enable **`BATTLE HUD: EXTENDED`** in Gen1Recomp.

The mod is designed around the extended widescreen layout and will not display correctly with the standard battle HUD.

## ⚙️ Configuration

Open **Gen1BetterMenus** in the Gen1Recomp Mod Manager.

Available settings:

**MENU PALETTE**  
Select the palette used for menus and UI panels.

**INVERSE**  
Reverse the selected palette from light-to-dark into dark-to-light.

Changes can be made directly through the Mod Manager.

## 🧩 Compatibility

Gen1BetterMenus currently targets:

**Gen1Recomp `>= 0.1.99` and `< 2.0.0`**

The mod is designed specifically for Gen1Recomp's widescreen rendering system.

It is compatible with **Groovy Palette & Frames** and should generally coexist with mods that do not replace or substantially modify the same UI/menu rendering code.

Mods that independently redesign menus, battle UI, dialogue boxes, or other interface components may conflict visually or functionally.

## 🚧 Current Status

Gen1BetterMenus is in active development.

Most major interface families have already been adapted for widescreen, but individual screens, edge cases, and visual inconsistencies may continue to be refined as development progresses.

Portrait-oriented layouts are planned for a future release.

## 🕹️ Project Goal

Gen1BetterMenus exists for players who want widescreen Pokémon without losing Pokémon Gen 1.
No modern dashboard.
No completely new visual language.
No attempt to make a 1990s Game Boy RPG look like a contemporary PC game.

Just **Gen 1, with room to breathe.**
