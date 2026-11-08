# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] - 2026-11-08

### Fixed
- **New Item Highlight Persistence Across Relogs**:
  - Prevented `AM.DB:UpdateBags()` from executing prematurely during `ADDON_LOADED` before container data is loaded by the client, which previously caused `charDB.seenItems` to be wiped on relog.
  - Added container readiness checks (`AM.DB:ArePlayerBagsLoaded()`) and a login settling guard in `PLAYER_ENTERING_WORLD` so `seenItems` is never purged while bag contents are still streaming from the server.
  - Standardized `AM:GetItemSeenKey()` to use deterministic, cache-independent `item:<itemID>` keys and updated bag scanning to read `itemID` directly without requiring cached hyperlinks.
  - Added automatic migration (`seenItemsMigratedV2`) to seed `seenItems` from saved bag, profession bag, and quiver inventories.

---

## [1.0.4] - 2026-11-07

### Added
- **Global Item Search Results Viewer**:
  - Interactive search window accessible via the main UI to search item names across all alts' bags, bank, and mailboxes.
  - Dynamically updates as `GET_ITEM_INFO_RECEIVED` events populate the client cache.
- **Enhanced Cross-Alt Tooltip Integration**:
  - Added full item location breakdown to item tooltips: Bags, Bank, Profession Bags (`Prof:`), Quiver, Mail, and active Auction House listings (`AH:`).
  - Displays a grand total line (`AltManager: Total: <count>`) across all tracked characters.
  - Alt names are displayed in their respective class colors.
  - Alts are sorted descending by quantity owned.
  - Modern `TooltipDataProcessor` integration (`Enum.TooltipDataType.Item`) with backward-compatible `OnTooltipSetItem` fallbacks.
- **Smart Gear Upgrade Scoring & Equip Restrictions**:
  - Deep restriction scanning via `C_TooltipInfo` and hidden tooltip scanning to detect red-text restrictions (class, level, or stat requirements).
  - Expected Armor Type checks (`AM_GetPlayerExpectedArmorType`) accounting for level 40 Mail/Plate transitions for Warriors, Paladins, Hunters, and Shamans.
  - Two-handed weapon upgrade logic evaluating against both Main Hand and Off-hand, ensuring 2H weapons must beat the highest equipped hand.
- **Profession Daily Cooldown Tracking**:
  - Automatically tracks daily tradeskill cooldowns (Alchemy Transmutes, Tailoring Mooncloth, Leatherworking Cured Rugged Hide, Refined Deepsea Salt).
  - Persists expiration timestamps and provides real-time readiness status across alts.
- **Bank Profession Bag Support**:
  - Extended bank scanning to track specialized profession bags (Herbalism, Mining, Engineering, Enchanting) and their separate capacity.
- **Mailbox Gold Tracking**:
  - Scans and aggregates pending gold waiting in alt mailboxes (`mailMoney`).

### Fixed
- **Bag UI Interaction & Lockups**:
  - Resolved issues where player bags occasionally became blocked or unresponsive during item swaps and bag updates.
- **Full Character Name Handling**:
  - Implemented `AM.DB:GetFullPlayerName()` across character viewers, database lookups, and auction tracking to properly support characters with last names on WoW Forever.
- **Tooltip Recursion Safeguard**:
  - Added `AM_InjectedItem` tracking and `OnTooltipCleared` hooks to prevent duplicate injection lines or tooltip flicker.
- **Auction Scanner Stability**:
  - Replaced ad-hoc auction tooltip creation with reusable singleton scanner (`AM.AuctionScanTooltip`) parented to `WorldFrame`.

---

## [1.0.3] - 2026-10-22

### Bugfix
- Fixed issue with some bag actions being blocked.

### Updated
- New scoring system for suggested upgrades in player bags.

---

## [1.0.2] - 2026-10-21

### Fixed
- Auto sort no longer removes the "trash" flags the player has manually assigned.
- Relogging on a character no longer marks the entire inventory as "new" (implemented persistent cache between sessions per character).

---

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

## [1.0.0] - 2026-10-10

### Added
- **Initial Release**:
  - Realmless scoping support across rulesets (PvE, PvP, Hardcore, RP) and factions.
  - Cross-character inventory (bags), bank, and currency tracking.
  - Rest XP tracking and mathematical calculation of offline rested accumulation.
  - Account wealth dashboard with per-character breakdown and total wealth footer.
  - Item tooltip injection showing cross-alt ownership quantities across bags and bank.
  - One-bag combined inventory viewer (`/am` or `/altmanager`) and minimap launcher icon.
