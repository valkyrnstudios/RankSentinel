# 1. Open https://docs.google.com/spreadsheets/d/1jtx1WyfChzACzh0WBWANtrqkRtS3D-zPWqs3eOnyVvY/edit#gid=0
# 2. Download as CSV to ".\AbilityData\bcc.csv"
# 2. Execute this script from root, "python .\AbilityData\Build.py"

from datetime import date

import csv, os

if not os.path.isdir('./AbilityData'):
  print('Must be run from Addon root')
  exit()

header = []
ability_list = []

with open('./AbilityData/bcc.csv', 'r', newline='') as csvfile:
  csvreader = csv.DictReader(csvfile)
  
  headers = next(csvreader)
  print('Parsing file with: ' + ', '.join(headers))

  excluded_count = 0

  for ability in csvreader:
    parsed_rank = ability['Rank'] if ability['Rank'] else 1

    rank_qualifier = ' (Rank {0})'.format(parsed_rank) if ability['Rank'] else ''

    if ability['Include'] != 'No':
      ability_list.append(
        "  [{0}] = {{ Name = \"{1}{2}\", Rank = {3}, Level = {4}, AbilityGroup = \"{5} - {6}\" }},\n"
          .format(ability['Ability ID'], ability['Ability'], rank_qualifier, parsed_rank, ability['Level'], ability['Class'], ability['Ability'])
        )
    else:
      print('Excluding {0}{1} - {2}'.format(ability['Ability'], rank_qualifier, ability['Note']))
      excluded_count += 1

  print('{0} Loaded / {1} Excluded abilities'.format(len(ability_list), excluded_count))

with open('./AbilityData.lua', 'w') as abilityData:
  abilityData.write('-- Built on {0}\n\n'.format(date.today()))
  abilityData.write('SpellSentinel.BCC = { }\n\n')
  abilityData.write('SpellSentinel.BCC.AbilityData = {\n')

  for ability in ability_list:
    abilityData.write(ability);

  abilityData.write('}\n')

#TODO add rank field to spell, create abilityGroup reverse lookup table with highest rank int
