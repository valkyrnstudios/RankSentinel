# SpellSentinel

SpellSnob was briefly available on [CurseForge](https://www.curseforge.com/wow/addons/SpellSnob) but was removed for unknown reasons. All original credit goes to \<Epoch of Thought\> - Whitemane. In accordance with the original [SpellSnob WTFPL](./SpellSnob.LICENSE), this project has been renamed SpellSentinel.

* **SpellSentinel** scans the combat log and alerts players who mistakenly use low-rank abilities, like the legacy add-on RankWatch.
* Many Legitimate Low-rank Abilities have already been excluded, like All Heals, Rank 1 Frost Bolt, Rank 1 Earth Shock, Rank 1 Blizzard, etc.
* If whisper is enabled, will only send one message per ability per time you are grouped up, spam should be minimal.

## Changes from SpellSnob

* Fix level calculation, no longer uses player's character for level comparison
* Convert to Ace3 libraries
* Replace CLI menu with AceGUI
