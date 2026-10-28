# VoidFrames — party/raid frames with click casting

**Status:** v1.0.0, first public release 2026-10-28. Built 2026-10-22 from scratch on Blizzard APIs: written from scratch, never copied from or marketed against another addon.

- Auras: Blizzard `CustomAuraContainer` (Blizzard_AuraContainer). HoTs `HELPFUL|PLAYER` (max 120s), debuffs `HARMFUL|RAID_IN_COMBAT`, cleanse slot `HARMFUL|RAID` (= what YOU can dispel), group buffs `HELPFUL` + spell-ID whitelist. Style/anchor inside `initializeFrame` (frames lock after init). Precreated out of combat (`PrepareAuraBoxes`).
- Clicks: Blizzard's Click Casting runs first and blocks `target`/`menu` on clicks without its interaction binding, so "target" is a `/target <unit>` macro. Defaults per spec (`SPEC_DEFAULTS`) else per class; `OLD_DEFAULTS` for upgrades.

| File | Role |
|---|---|
| `Core.lua` | Defaults, per-class starting bindings (from the user's old click setup), bindings storage `VoidFramesDB.bindings[Name-Realm][specIndex]`, options panel, `/vframes` (`/vframes bind`) |
| `Frames.lua` | Fixed `SecureUnitButtonTemplate` buttons: player+party1-4 (party box) and raid1-40 (raid box), `RegisterUnitWatch` + state drivers for visibility; visuals on a plain `vis` child |
| `BindingsEditor.lua` | 5 mouse buttons × 4 modifiers grid; type a spell / target / focus / menu / assist, or drag from spellbook |

**Rules:**
- Click attributes (`<mod>type<btn>`, `<mod>spell<btn>`) only change out of combat; changes in combat are queued to `PLAYER_REGEN_ENABLED`. Same for layout.
- Range: `UnitInRange` returns are secret → `vis:SetAlphaFromBoolean(inRange, 1, 0.4)`.
- Auras via filters: `HELPFUL|PLAYER` (your HoTs), `HARMFUL|RAID` (debuffs), `HARMFUL|RAID_PLAYER_DISPELLABLE` (purple border).
- Raid order is raid index, not subgroup (v0.1).
- Blizzard party/raid frames are NOT hidden by the addon — the user turns them off in Edit Mode.
