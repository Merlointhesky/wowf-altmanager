# CHANGES for version 1.0.2

- auto sort also removes the "trash" flags the player has added manually, it shouldn't
- relogging on a character makes the whole inventory "new". We should keep a cache between logging sessions for each character to know which items are new or not and keep tehm as such. 