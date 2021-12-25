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
reverse_lookup = {}

with open('./AbilityData/bcc.csv', 'r', newline='') as csvfile:
  csvreader = csv.DictReader(csvfile)
  
  headers = next(csvreader)
  print('Parsing file with: ' + ', '.join(headers))

  excluded_count = 0

  for ability in csvreader:
    parsed_rank = ability['Rank'] if ability['Rank'] else 1

    if ability['Include'] != 'No':
      ability_group = '{0} - {1}'.format(ability['Class'], ability['Ability'])
      ability_list.append(
        "  [{0}] = {{ Rank = {1}, Level = {2}, AbilityGroup = \"{3}\" }},\n"
          .format(ability['Ability ID'], parsed_rank, ability['Level'], ability_group)
        )

      if not ability_group in reverse_lookup:
        reverse_lookup[ability_group] = {}

      reverse_lookup[ability_group][ability['Ability ID']] = parsed_rank

    else:
      print('Excluding {0}{1} - {2}'.format(ability['Ability'], parsed_rank, ability['Note']))
      excluded_count += 1

  print('{0} Loaded / {1} Excluded abilities'.format(len(ability_list), excluded_count))



with open('./AbilityData.lua', 'w', newline='') as abilityData:
  abilityData.write('-- Built on {0}\n\n'.format(date.today()))
  abilityData.write('SpellSentinel.BCC = { }\n\n')
  abilityData.write('SpellSentinel.BCC.AbilityData = {\n')

  for ability in ability_list:
    abilityData.write(ability);

  abilityData.write('}\n\n')

  abilityData.write('SpellSentinel.BCC.AbilityGroups = {\n')
  for key, abilityGroup in reverse_lookup.items():
    abilityData.write('  [\"{0}\"] = {{ {1} }},\n'.format(key, ', '.join(abilityGroup) ));

  abilityData.write('}\n')
