# RankSentinel

RankSentinel detect players (and now pets!) using lower ranked abilities and notifies them. Inspired by the legacy add-on [RankWatch](https://www.curseforge.com/wow/addons/rankwatch).

RankSentinel is a [spiritual successor to the now defunct GogoWatch](https://github.com/valkyrnstudios/RankSentinel/issues/5) and SpellSnob add-ons.

Legitimate Low-rank Abilities have been excluded; including All Heals, Rank 1 Frost Bolt, Rank 1 Earth Shock, Rank 1 Blizzard, etc.

## Commands

Use `/ranksentinel` to get the latest commands.

- `/ranksentinel enable`: toggles combat log parsing
- `/ranksentinel whisper`: toggles whispers to players
- `/ranksentinel combat`: toggles whispers to players during combat
- `/ranksentinel reset`: resets profile to defaults
- `/ranksentinel count`: prints current statistics
- `/ranksentinel debug`: toggles debug output for testing
- `/ranksentinel clear`: clears local ability caches
- `/ranksentinel cluster`: prints cluster members
- `/ranksentinel cluster reset`: resets cluster to defaults
- `/ranksentinel cluster elect`: triggers lead election logic
- `/ranksentinel ignore playerName`: ignores all abilities cast by playerName

## Vanilla support

[Classic Era and Season of Mastery realm combat logs do not support spellID](https://wowpedia.fandom.com/wiki/Patch_1.13.2/API_changes), as such this addon is limited to the current player's abilities.

## Reporting issues

Ability data comes from [Gogo's revised ability list](https://docs.google.com/spreadsheets/d/1jtx1WyfChzACzh0WBWANtrqkRtS3D-zPWqs3eOnyVvY/edit?usp=sharing), please leave a comment for any ability data changes you have in mind.

[RankSentinel github issues](https://github.com/valkyrnstudios/RankSentinel/issues) and [CurseForge project comments](https://www.curseforge.com/wow/addons/ranksentinel) are a great location to report problems.

## Contributors

- Gogo - for continued addon collaboration and data curation
- Aevala and Fathom - ability data feedback, exclusions
- Splendiferus - for continued testing and feedback
