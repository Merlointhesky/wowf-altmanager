# Forever Alt Manager

**Version:** 1.0.0  
**WoW Version:** WoW Forever Beta (v1.60.1)  
**Interface:** `16001`  

## Description
A comprehensive alt management tool designed for the WoW Forever Beta. It tracks characters, their wealth, inventory, bank, and professions across the account, and injects helpful ownership tooltips onto items.

## Features
- **Character Cache Database:** Tracks Classes, Levels, Professions, Inventory (Bags), Bank, and Mail. Also tracks Rest XP with real-time accumulation calculations.
- **Wealth Tracking:** Displays total gold across all characters on the same ruleset/faction.
- **Contextual Visibility:** Filters data (and aggregate totals) to only show characters on the *same* ruleset (PvE, PvP, RP, or Hardcore) and Faction.
- **Tooltip Integration:** Appends custom lines to item tooltips indicating which other characters own the item, quantities, and location (bags/bank).
- **Profession Cooldown Tracking:** Tracks active daily/profession cooldowns across alts.
- **Main UI Dashboard:** Accessible via `/altmanager` or `/am`, or via the Minimap icon.

## Important Note for WoW Forever Beta
Due to a known beta bug preventing `SavedVariables` from persisting on logout, this addon implements a local manual serialization workaround to ensure your data is safely stored between sessions. Data is also strictly scoped via `[Ruleset][Faction]` to respect the realmless nature of WoW Forever.
