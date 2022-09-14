# 1. Open https://docs.google.com/spreadsheets/d/1jtx1WyfChzACzh0WBWANtrqkRtS3D-zPWqs3eOnyVvY/edit#gid=0
# 2. Download "TBC Abilities" as CSV to ".\AbilityData\tbc.csv"
# 3. Download "Wrath Abilities" as CSV to ".\AbilityData\wrath.csv"
# 4. Execute this script from root, "python .\AbilityData\Build.py"

from datetime import date

import csv, os

if not os.path.isdir('./AbilityData'):
  print('Must be run from Addon root')
  exit()

eras = {
  "Wrath.lua": 'wrath.csv'
}

for eraLua, eraCsv in eras.items():
  if not os.path.exists('./AbilityData/{0}'.format(eraCsv)):
    print('{0} not found'.format(eraCsv));
    continue

  header = []
  ability_list = []
  reverse_lookup = {}

  with open('./AbilityData/{0}'.format(eraCsv), 'r', newline='') as csvfile:
    csvreader = csv.DictReader(csvfile)

    headers = next(csvreader)
    print('Parsing file with: ' + ', '.join(headers))

    excluded_count = 0
    ability_group_lookup = {}

    for ability in csvreader:
      parsed_rank = ability['Rank'] if ability['Rank'] else 1

      if ability['Include'] != 'No':
        ability_group_name = '{0} - {1}'.format(ability['Class'], ability['Ability'])

        if not ability_group_name in ability_group_lookup:
          ability_group_lookup[ability_group_name] = {}

        ability_group_id = len(ability_group_lookup)

        ability_group_lookup[ability_group_name] = ability_group_id

        ability_list.append(
          "  [{0}] = {{ Rank = {1}, Level = {2}, AbilityGroup = {3} }},\n"
            .format(ability['Ability ID'], parsed_rank, ability['Level'], ability_group_id)
          )

        if not ability_group_id in reverse_lookup:
          reverse_lookup[ability_group_id] = {}

        reverse_lookup[ability_group_id][ability['Ability ID']] = parsed_rank

      else:
        print('Excluding {0} {1} - {2}'.format(ability['Ability'], parsed_rank, ability['Note']))
        excluded_count += 1

    print('{0} Loaded / {1} Excluded abilities'.format(len(ability_list), excluded_count))

  with open('./AbilityData/{0}'.format(eraLua), 'w', newline='') as abilityData:
    abilityData.write('-- Built on {0}\n\n'.format(date.today()))
    abilityData.write('local _, addon = ...\n\n')
    abilityData.write('addon.AbilityData = {\n')

    for ability in ability_list:
      abilityData.write(ability);

    abilityData.write('}\n\n')

    abilityData.write('addon.AbilityGroups = {\n')
    for key, abilityGroup in reverse_lookup.items():
      abilityData.write('  {{ {1} }},\n'.format(key, ', '.join(abilityGroup) ));

    abilityData.write('}\n')
