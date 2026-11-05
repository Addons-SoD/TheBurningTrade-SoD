# The Burning Trade

A World of Warcraft add-on that enhances the trade window and keeps a detailed log of every trade you make. It provides class-specific trade helper buttons for Mages, Warlocks, and Rogues, plus a full trade history panel accessible from a minimap button. Originally written for Classic Era / Season of Discovery, this branch is ported to **WoW Forever** (client directory `_forever_`, product code `wowf`, Interface `16001`).

This is a standalone build with all external library dependencies stripped, so it runs on its own without requiring any other add-on.

## Features

### Trade Log

- Records every trade automatically, including:
  - Items given and received (with counts and enchantments)
  - Money given and received
  - Trade result: completed, cancelled, or failed
  - Analysis of the cancellation reason (you cancelled, target cancelled, too far away, etc.)
- Prints a summary line to the chat frame after each trade, with a clickable **Detail** link.
- Clicking the detail link opens a window showing the full trade breakdown.
- Keeps a persistent history of past trades.
- A minimap button opens the trade list panel, where you can browse, filter, and review previous trades.
- Optionally announce the result of a trade to Whisper / Party / Raid / Say / Yell.
- Option to keep only today's records when clearing history.

### Trade Frame Enhancement

Adds helpful buttons directly onto the trade window:

- **Mage** – Conjure Water and Conjure Food buttons that automatically place the appropriate items into the trade, plus a portal selector with a radial portal picker.
- **Warlock** – Healthstone button that finds and places your own healthstone into the trade.
- **Rogue** – Pick Lock button.
- Shows the trade target's class and level on the trade window.
- Whisper button to start a conversation with the trade target.
- Quick emote buttons (hungry / thank).
- Auto-loots a single enchant result when disenchanting during a trade.

## Slash Commands

| Command | Description |
| ------- | ----------- |
| `/tbtdebug <id>` | Dump the details of a stored trade by its history id. |

## Installation

1. Download or clone this repository.
2. Copy the folder into your World of Warcraft `Interface/AddOns` directory, e.g.
   `World of Warcraft\_forever_\Interface\AddOns\TheBurningTrade`.
3. The folder must be named `TheBurningTrade`.
4. Restart the game or reload the UI.

The add-on has **no external dependencies** and works standalone.

## Compatibility

- World of Warcraft: Forever (`_forever_` client, product code `wowf`, version 1.60.1)
- Interface: `16001` (modern Mainline ~12.1.5 API, Lua 5.1)
- `ForeverCompat.lua` is loaded first and maps the removed classic APIs to their modern
  equivalents (`C_Container`, `C_Item`, `C_SpellBook`, `C_TradeInfo`, `C_EventUtils`),
  with capability probing so missing APIs degrade gracefully instead of throwing errors.

## License

This project is licensed under the [MIT License](LICENSE).
