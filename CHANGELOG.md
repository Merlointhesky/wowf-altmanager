# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-10-19

### Added
- **New Item Bag Highlighting**:
  - Automatically highlights new items in player bags with an animated golden border overlay (`btn.AM_NewItemGlow` and native Blizzard glow).
  - Highlighting persists across sessions until the player directly mouses over the item.
  - Smart stackable handling: for stackable goods (cloth, ores, herbs, etc.), only the first acquisition highlights; subsequent additions or new stacks of the same item do not trigger false alerts.
  - Non-stackable gear, weapons, and items are tracked individually by unique GUID/instance keys and highlight per drop.
  - Cache auto-pruning: when an item is sold to a vendor, consumed, destroyed, or deleted from player bags, it is pruned from the cache so re-acquiring it later highlights appropriately.
  - Strictly scoped to player bags (bank and alt inventory views remain unaffected).
- **Show Ignored Characters Option**:
  - Added a "Show Ignored" checkbox to the MainFrame footer.
  - When checked, ignored alts are visible at reduced opacity (50%) with an `[Ignored]` badge, allowing users to unignore them at any time.
- **Auction Tracking**:
  - Track live and cached auction house listings per alt.
  - Added dedicated auction overview with item icons, counts, time remaining, buyout prices, and net earnings (5% AH cut calculator).
- **Mail Alerts & Unread Indicators**:
  - Added real-time indicators for unread mail.
  - Added animated mail glow effect when an alt has pending unread mail or expired auction deliveries.
- **Recipe & Profession Browser**:
  - Added an interactive recipe viewer to inspect known tradeskill recipes across all alts.
- **Alternative Slash Commands**:
  - Added `/fam` and `/foreveraltmanager` aliases in addition to `/am` and `/altmanager`.
- **Blizzard Combined Backpack (One Bag) Replacement**:
  - Hooked Blizzard's native `ContainerFrameCombinedBags`, `OpenBackpack`, `CloseBackpack`, `OpenBag`, `CloseBag`, and `CVAR_UPDATE` (`combinedBags`).
  - Seamlessly replaces Blizzard's native one-bag view with Forever Alt Manager's one-bag view when changing modes on the real UI.
  - Registered all inventory windows in `UISpecialFrames` to support Escape key closure.

### Fixed
- **Character Deletion**:
  - Fixed an issue where clicking "Delete" in the confirmation popup did nothing due to missing `dialog.data` arguments in `StaticPopup_Show`.
  - Moved `StaticPopupDialogs` definitions to top-level module scope to avoid re-registration on every refresh.
  - Added cleanup logic to close active item viewers and alt inventory sub-frames when a character is deleted.
  - Prevented self-deletion of the character currently being played.
- **Account Wealth & Ignore Recalculation**:
  - Fixed an issue where ignoring a character did not update the total account wealth. Ignored characters are now immediately excluded from the footer wealth sum upon toggling.
  - Fixed row reuse bugs in `RefreshData()` caused by unincremented row indexes for ignored characters.
  - Excluded ignored characters from item tooltip counts and bag wealth listings.
- **Profession Bag Duplication**:
  - Fixed profession bag and quiver items mistakenly duplicating into the regular main bags view.
  - Separated profession bags (Herbalism, Mining, Engineering, Enchanting) and quivers/pouches into dedicated visual sections.
- **Profession Recipe Persistence**:
  - Fixed character profession updates accidentally wiping existing recipe lists. Missing professions are now cleaned up without corrupting valid tradeskill data.
- **Bank Indexing & Container Compatibility**:
  - Modernized bank indexing using `Enum.BagIndex.Bank` and live bank bag scanning instead of deprecated `BANK_CONTAINER` constants.
  - Migrated legacy container calls to `C_Container` APIs in compliance with the WoW Forever Beta engine.
- **Combined Backpack Compatibility**:
  - Fixed issues where the combined backpack was not hidden when opening the Alt Manager Bags.

### Changed
- Renamed project TOC file to `ForeverAltManager.toc` and updated title to **Forever Alt Manager**.
- Cleaned up redundant layout and duplicate UI definitions across `UI.lua` and `BagUI.lua`.

---
## [1.0.2] - 2026-10-21

### Fixed
- Auto sort also removes the "trash" flags the player has added manually; this behavior has been corrected.
- Relogging on a character no longer marks the entire inventory as "new". Implemented persistent cache between sessions per character to retain item newness state.

---
## [1.0.0] - 2026-10-10

### Added
- **Initial Release**:
  - Realmless scoping support across rulesets (PvE, PvP, Hardcore, RP) and factions.
  - Cross-character inventory (bags), bank, and currency tracking.
  - Rest XP tracking and mathematical calculation of offline rested accumulation.
  - Account wealth dashboard with per-character breakdown and total wealth footer.
  - Item tooltip injection showing cross-alt ownership quantities across bags and bank.
  - One-bag combined inventory viewer (`/am` or `/altmanager`) and minimap launcher icon.
