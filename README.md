# RankSentinel

RankSentinel detects group members (and now pets!) using lower ranked abilities and notifies them.

Ensure your raid group are getting the maximum performance out of their abilities. This addon has already caught so many pugs and guildies alike during testing who had no idea they were using an outdated rank.

Legitimate low-rank Abilities have been excluded; including all heals, Frostbolt (Rank 1), Earth Shock (Rank 1), Blizzard (Rank 1), etc.

A large focus has been on delivering the most optimized code possible, memory usage is ~724K in 5-mans and ~743K in 25-mans.

Inspired by the legacy add-on [RankWatch](https://www.curseforge.com/wow/addons/rankwatch), RankSentinel is a [spiritual successor to the now defunct GogoWatch](https://github.com/valkyrnstudios/RankSentinel/issues/5) and SpellSnob add-ons.

## Commands

Use `/ranksentinel` to get the latest commands.

- `/ranksentinel enable`: toggles combat log parsing
- `/ranksentinel whisper`: toggles whispers to players
- `/ranksentinel combat`: toggles whispers to players during combat
- `/ranksentinel reset`: resets profile to defaults
- `/ranksentinel count`: prints current statistics
- `/ranksentinel debug`: toggles debug output for testing
- `/ranksentinel clear`: clears local ability caches
- `/ranksentinel lead`: sets yourself as lead
- `/ranksentinel ignore`: adds current target to addon ignore list, will not report rank errors

## Vanilla support

[Classic Era and Season of Mastery realm combat logs do not support spellID](https://wowpedia.fandom.com/wiki/Patch_1.13.2/API_changes), as such this addon is limited to the current player's abilities.

## Reporting issues

Ability data comes from [Gogo's revised ability list](https://docs.google.com/spreadsheets/d/1jtx1WyfChzACzh0WBWANtrqkRtS3D-zPWqs3eOnyVvY/edit?usp=sharing), please leave a comment for any ability data changes you have in mind.

[RankSentinel github issues](https://github.com/valkyrnstudios/RankSentinel/issues) and [CurseForge project comments](https://www.curseforge.com/wow/addons/ranksentinel) are a great location to report problems.

## Contributors

- Gogo - for continued addon collaboration and data curation
- Aevala and Fathom - ability data feedback, exclusions
- Splendiferus - for continued testing and feedback
