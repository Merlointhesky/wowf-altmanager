# CHANGES for version 1.0.1

- [x] BUG: cannot delete characters - after clicking on delete we get the popup but then clicking on "delete" on the popup doesn't do anything. (FIXED: Passed target character data to `StaticPopup_Show`, moved dialog to module scope, and purged child frames)
- [x] BUG: ignoring characters should immediately change the total wealth owned in the ALT manager view (FIXED: Ignored alts are excluded from wealth accumulation immediately, added "Show Ignored" checkbox to unignore)
- [x] new feature: highlight new items in the bags once. Keep a cache of previously seen items and remove it when the item is sold or deleted from the bags. This only applies to player bags. (IMPLEMENTED: Stackables highlight on first acquisition and ignore subsequent duplicates; non-stackables highlight per instance; highlights persist until moused over; sold/deleted items are pruned from the cache)

