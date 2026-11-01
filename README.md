# VoidFrames

**Clean party and raid frames with click casting built in, and your HoTs, debuffs and cleanses still visible in combat.**

VoidFrames replaces Blizzard's party and raid frames with flat, readable boxes you can heal and cleanse straight from. Click a frame to cast on that player, with a spell on every mouse button and modifier, set per character and per spec. Your HoTs, their debuffs and their group buffs stay on the frames during fights, built on Blizzard's own aura display so they keep working under Midnight's combat rules.

---

## Features

### Click casting
- **Any spell on any click** — left, right, middle, buttons 4 and 5, each with Click / Shift / Ctrl / Alt, so 20 bindings per spec
- **Target, focus, menu or assist** on a click as well as spells
- **Per character and per spec** — your Restoration clicks and your Guardian clicks are kept apart and swap when you change spec
- **Ready on day one** — every class and spec starts with sensible clicks: healers get their heals and cleanse, tanks and damage dealers get target / menu / focus plus their class's group help (battle rez, Tricks of the Trade, Power Word: Shield, Misdirection, ...)
- **Easy editor** — type a spell name or drag it from your spellbook onto a box; clearing a box unbinds it for good

### See what matters in combat
- **Your HoTs and shields** on each frame with timers and stacks (Lifebloom stacks, Rejuvenation, Riptide, Renewing Mist, Echo, Atonement, ...) — they stay visible for the whole fight
- **Debuffs** on each frame — the ones Blizzard's own raid frames show in combat, boss debuffs included — bordered in their dispel type's color (Magic, Curse, Poison, Disease)
- **Cleanse button** — a square to the right of each party frame lights up with a debuff **your** cleanse can remove; click it to cleanse that player
- **Group buffs above each frame** — Mark of the Wild, Arcane Intellect, Power Word: Fortitude, Battle Shout, Skyfury and Blessing of the Bronze, whoever cast them
- **Who's missing your buff** — your class's group buff (Druid, Mage, Priest, Warrior, Shaman, Evoker) shows on anyone who doesn't have it, out of combat, so you know who to rebuff
- **Role icons, raid markers, class colors**, "Dead" and "Offline"
- **Out-of-range fading** and a white outline on your current target

### Party and raid layouts
- **Party frames** (you plus four) in a column, **raid frames** in a grid
- **Raid frames shrink as the raid grows** — full size up to 5, smaller at 10, 20 and 40 players, so a full raid still fits
- **Frame width, height, frames per row and opacity**, all adjustable
- **Move them** — hold Alt and drag any frame to move the whole group
- **Hides Blizzard's party and raid frames** so you only see one set (optional)

---

## Slash Commands

| Command | What it does |
|---|---|
| `/vframes` | Open the VoidFrames options |
| `/vframes bind` | Open the click bindings editor |

---

## Getting Started

1. Install with the CurseForge app, or copy the `VoidFrames` folder into `World of Warcraft/_retail_/Interface/AddOns/`.
2. Restart WoW or `/reload`.
3. Join a group: your party frames appear on the left. Hold Alt and drag one to move them.
4. Type `/vframes bind` (or Esc → Options → AddOns → VoidFrames → Edit click bindings) to see or change what each click does for your spec.

---

## Default Clicks

Every spec starts with these until you change them. Bindings you set yourself are kept when the defaults are updated.

**Healers** — click heals, right-click cleanses, Middle = target, Alt+Left = target, Alt+Right = focus:

| Spec | Click | Shift + Click | Ctrl + Click | Right | Shift + Right | Ctrl + Right | Shift / Ctrl + Middle |
|---|---|---|---|---|---|---|---|
| Restoration Druid | Rejuvenation | Lifebloom | Regrowth | Nature's Cure | Rebirth | Ironbark | Innervate |
| Restoration Shaman | Riptide | Healing Wave | Chain Heal | Purify Spirit | Earth Shield | Unleash Life | — |
| Mistweaver Monk | Renewing Mist | Vivify | Enveloping Mist | Detox | Life Cocoon | Soothing Mist | Tiger's Lust |
| Preservation Evoker | Echo | Living Flame | Verdant Embrace | Naturalize | Time Dilation | Reversion | Rescue / Cauterizing Flame |
| Holy Priest | Flash Heal | Prayer of Mending | Holy Word: Serenity | Purify | Guardian Spirit | Power Infusion | Leap of Faith |
| Discipline Priest | Power Word: Shield | Flash Heal | Penance | Purify | Pain Suppression | Plea | Leap of Faith / Power Infusion |
| Holy Paladin | Holy Shock | Flash of Light | Word of Glory | Cleanse | Blessing of Sacrifice | Holy Light | Blessing of Protection / Lay on Hands |

Holy Paladin also gets Blessing of Freedom on mouse button 4 and Intercession on button 5.

**Tanks and damage dealers** — Click = target, Right = menu, Middle = focus, Ctrl + Click = focus, plus your class's group help:

| Class | Shift + Click | Shift + Right | Shift + Middle | Ctrl + Right / Middle |
|---|---|---|---|---|
| Death Knight | Raise Ally | — | — | — |
| Druid | Rebirth | Remove Corruption | Innervate | — |
| Evoker (Devastation) | Rescue | Expunge | Verdant Embrace | — |
| Evoker (Augmentation) | Prescience | Blistering Scales | Rescue | Expunge |
| Hunter | Misdirection | — | — | — |
| Mage | Remove Curse | — | — | — |
| Monk | Tiger's Lust | Detox | Vivify | — |
| Paladin | Intercession | Cleanse Toxins | Blessing of Protection | Blessing of Freedom / Lay on Hands |
| Priest (Shadow) | Power Word: Shield | Purify Disease | Leap of Faith | Power Infusion |
| Rogue | Tricks of the Trade | — | — | — |
| Shaman | Healing Surge | Cleanse Spirit | Earth Shield | — |
| Warlock | Soulstone | — | — | — |
| Warrior | Intervene | — | — | — |
| Demon Hunter | — | — | — | — |

A spell you haven't learned or talented simply does nothing when clicked; bind something else in its place any time.

---

## Good to Know

- **Blizzard's own Click Casting comes first.** A spell or macro bound in the game's Click Casting (Esc → Options → Click Casting) on the same click wins over VoidFrames; clear it there to use VoidFrames for that click. The player menu only opens on a plain right-click (the game's rule), so healers, whose right-click cleanses, open it from the player's portrait instead.
- **Bindings, layout and size only change out of combat.** A change made mid-fight is applied as soon as combat ends.
- **Midnight hides group members' auras from addons during instance fights.** VoidFrames hands that work to Blizzard's own aura display, so HoTs, debuffs, the cleanse button and group buffs keep showing in Mythic+ and raids. The "missing your buff" check reads auras directly, so it only runs out of combat.
- **The cleanse button is always clickable.** With nothing to remove, the click just fails without using your cooldown.
- **Raid frames have no cleanse square** (they sit side by side); right-click the frame instead if your spec's default does it, or bind your cleanse to a click.
- Bindings are saved per character and spec; layout and look are saved account-wide.

---

## Compatibility

- **WoW 12.1.5** (Midnight Season 2)
- Standalone — nothing else to install
- **Default clicks use English spell names.** On other client languages, set your clicks once in the editor (typing or dragging a spell works in any language).
- Works alongside other addons; turn off "Hide Blizzard party and raid frames" if you want to keep Blizzard's as well

---

*Part of the Void addon family by Vede · MIT licensed · [Source & bug reports](https://github.com/bughatti/voidframes) · [All Void addons](https://www.curseforge.com/members/bughatti/projects) · free M+ & raid player lookups at [voidscout.io](https://voidscout.io) · more at [tinkerline.io](https://tinkerline.io) · [Discord](https://discord.gg/7ZHmx7zMDh)*
