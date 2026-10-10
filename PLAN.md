# ALT MANAGER

- **Version**: 1.0.0
- **WoW Version**: WoW Forever Beta (v1.60.1)
- **Interface**: `16001`

## Description
A comprehensive alt management tool designed for the WoW Forever Beta. It tracks characters, their wealth, inventory, bank, and professions across the account, and injects helpful ownership tooltips onto items.

## 1. Core Architecture and Constraints
*   **Modern API Architecture**: Uses the Retail/Midnight-era engine API (Lua 5.1). We must use modern namespaces like `C_Container` instead of legacy global functions (e.g., `GetContainerNumSlots`).
*   **Realmless Scoping**: Traditional servers are replaced by rulesets (Normal, PvP, Hardcore, RP). Data will be mapped securely via `[Ruleset][Faction]` to avoid cross-pollination.
*   **SavedVariables Beta Bug Workaround**: Due to a beta bug preventing `SavedVariables` from persisting on logout, the addon will implement a local manual serialization workaround (or integrate with `ForeverSVFix`) to ensure data is safely stored between sessions.

## 2. Features and Functionality
1.  **Character Cache Database**:
    *   Maintain a cached list of all characters.
    *   Track Classes, Levels, Professions, Inventory (Bags), Bank, with precise item IDs, links, and quantities.
    *   **Mail Tracking**: Track items and gold currently sitting in a character's mailbox (updates when mail is sent to them by another alt, or when they view their inbox).
    *   **Rest XP Tracking**: Cache current rest XP, maximum XP, logout time, and resting state (`IsResting()`). The UI will mathematically calculate and display real-time accumulated offline rested XP (capped at 1.5 levels).
2.  **Wealth Tracking**:
    *   Keep a list of money possessed by each character.
    *   Display a summed total of gold across all characters on the same ruleset/faction.
3.  **Contextual Visibility (Ruleset Filtering)**:
    *   Only show data (and aggregate totals) for characters on the *same* ruleset (PvE, PvP, RP, or Hardcore) and Faction.
4.  **Tooltip Integration**:
    *   When mousing over an item anywhere in the UI (recipe, bag, quest, chat link, etc.), the addon will append custom lines to the tooltip.
    *   The tooltip will display which other characters on the same ruleset/faction own the item, their quantities, and whether it's in their bags or bank.
    *   *Implementation Note*: Use modern Retail tooltip hooking (e.g., `TooltipDataProcessor` or `C_TooltipInfo` if available, or hooking `GameTooltip:OnTooltipSetItem`).
5.  **Profession Cooldown Tracking**:
    *   Track active daily/profession cooldowns (e.g., Alchemy transmutes, Tailoring cloth) across alts to easily see who is ready for their daily crafts.
6.  **Main UI Dashboard (`/altmanager` or `/am`)**:
    *   **Minimap Icon**: A minimap button to easily toggle the interface.
    *   **Character List**: A clean, scrollable interface displaying characters on the current ruleset/faction.
    *   **Action Icons**: For each character, there will be discrete icons to:
        *   Open/View their Bags.
        *   Open/View their Bank.
        *   Open/View their Mail (only visible if mail actually exists).
    *   **Wealth Column**: The far-right column will display the exact money owned by each character, formatted nicely with WoW coin icons.