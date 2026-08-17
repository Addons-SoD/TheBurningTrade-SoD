# The Burning Trade

A World of Warcraft Classic Era add-on that enhances the trade window and keeps a detailed log of every trade you make. It provides class-specific trade helper buttons for Mages, Warlocks, and Rogues, plus a full trade history panel accessible from a minimap button.

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
   `World of Warcraft\_classic_era_\Interface\AddOns\TheBurningTrade`.
3. The folder must be named `TheBurningTrade`.
4. Restart the game or reload the UI.

The add-on has **no external dependencies** and works standalone.

## Compatibility

- World of Warcraft Classic Era / Season of Discovery
- Interface: `11508`

## License

This project is licensed under the [MIT License](LICENSE).
