# 1. Open https://docs.google.com/spreadsheets/d/1jtx1WyfChzACzh0WBWANtrqkRtS3D-zPWqs3eOnyVvY/edit#gid=0
# 2. Download as CSV to "AbilityData/WoW TBC ability list - TBC Abilities.csv"
# 2. Execute this script from root, "python .\AbilityData\Build.py"

import csv, os

if not os.path.isdir('./AbilityData'):
  print('Must be run from Addon root')
  exit()

header = []
ability_list = []

with open('./AbilityData/WoW TBC ability list - TBC Abilities.csv', 'r', newline='') as csvfile:
  csvreader = csv.DictReader(csvfile)
  
  headers = next(csvreader)
  print('Parsing file with: ' + ', '.join(headers))

  for ability in csvreader:
    rank_qualifier = ' (Rank {0})'.format(ability['Rank']) if ability['Rank'] else ''

    if ability['Include'] != 'No':
      ability_list.append("  [{0}] = {{ Name = \"{1}{2}\", Level = {3}, AbilityGroup = \"{4} - {5}\" }},\n".format(ability['Ability ID'], ability['Ability'], rank_qualifier, ability['Level'], ability['Class'], ability['Ability']))
    else:
      print('Excluding {0}{1} - {2}'.format(ability['Ability'], rank_qualifier, ability['Note']))

  print('Loaded {0} abilities'.format(len(ability_list)))

with open('./AbilityData.lua', 'w') as abilityData:
  abilityData.write('SpellSentinel.AbilityData = {\n')

  for ability in ability_list:
    abilityData.write(ability);

  abilityData.write('\n}\n')
