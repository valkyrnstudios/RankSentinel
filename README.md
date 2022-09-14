# RankSentinel

RankSentinel watches the combat log and detects when group members (and now their pets!) accidentally use a low-rank ability and sends them a private message so they can fix the issue. It's inspired by the legacy add-on [RankWatch](https://www.curseforge.com/wow/addons/rankwatch).

We built this tool to help your raid group make small improvements so they can avoid those 1%-wipe situations. In testing it detected so many guildies, friends, and PUGs who had just forgotten to update their action bars or macros after training. Everyone has at least one ability they forgot to update. Everyone.

- Legitimate low-rank Abilities have been excluded
- Battlegrounds are also excluded
- Ability data comes from [Gogo's revised ability list](https://docs.google.com/spreadsheets/d/1jtx1WyfChzACzh0WBWANtrqkRtS3D-zPWqs3eOnyVvY/edit?usp=sharing), please leave a comment for any ability data changes you have in mind.
- A large focus has been on delivering the most optimized code possible, memory usage is significantly less than Questie, your favorite damage meter, or inventory management add-on.
- RankSentinel's [GitHub issues](https://github.com/valkyrnstudios/RankSentinel/issues) and [CurseForge comments](https://www.curseforge.com/wow/addons/ranksentinel) are great locations to report any issues you find.
- RankSentinel is a [spiritual successor](https://github.com/valkyrnstudios/RankSentinel/issues/5) to the now-defunct GogoWatch and SpellSnob add-ons.

## Commands

Use `/ranksentinel` to get the latest commands.

- `/ranksentinel enable`: toggles combat log parsing
- `/ranksentinel whisper`: toggles whispers to players
- `/ranksentinel report [channel]`: report session data [self, say, raid, guild]
- `/ranksentinel count`: prints current statistics
- `/ranksentinel lead`: sets yourself as lead
- `/ranksentinel flavor`: list available notification flavors
- `/ranksentinel flavor [option]`: set notification flavor to option
- `/ranksentinel advanced`: Advanced command-line options

Use `/ranksentinel advanced` to get additional commands.

- `/ranksentinel debug`: toggles debug output for testing
- `/ranksentinel clear`: clears local ability caches
- `/ranksentinel ignore`: adds current target to addon ignore list, will not report rank errors
- `/ranksentinel queue`: prints queued notifications
- `/ranksentinel queue clear`: clears queued notifications
- `/ranksentinel queue process`: processes queued notifications
- `/ranksentinel reset`: resets profile to defaults
- `/ranksentinel sync`: broadcast announcement cache

## Contributors

- Gogo - for continued addon collaboration and data curation
- Aevala and Fathom - ability data feedback
- Splendiferus - for continued testing and feedback
