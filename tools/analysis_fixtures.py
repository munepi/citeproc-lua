import glob
from collections import Counter
import os
import re
from unicodedata import name
import xml.etree.ElementTree as ET

failed_fixtures = []
skipped_fixtures = [
    'affix_MovingPunctuation.txt',
    'bugreports_ApostropheOnParticle.txt',
    'bugreports_ArabicLocale.txt',
    'bugreports_FrenchApostrophe.txt',
    'bugreports_TitleCase.txt',
    'bugreports_EtAlSubsequent.txt',
    'integration_DeleteName.txt',
    'magic_CapitalizeFirstOccurringNameParticle.txt',
    'locale_TitleCaseEmptyLangEmptyLocale.txt',
    'locale_TitleCaseGarbageLangEmptyLocale.txt',
    'magic_StripPeriodsFalse.txt',
    'magic_StripPeriodsTrue.txt',
    'punctuation_FrenchOrthography.txt',
]

with open('./test/citeproc-test.log') as f:
    for line in f:
        if line.startswith('Failure → citeproc test test-suite') or \
            line.startswith('Error → citeproc test test-suite'):
            failure_file = line.split()[-1]
            failed_fixtures.append(failure_file)


namespaces = {
    'cs': 'http://purl.org/net/xbiblio/csl',
}

num_tags = dict()

# paths = sorted(glob.glob('./test/test-suite/processor-tests/humans/*.txt'))
paths = sorted(['./test/test-suite/processor-tests/humans/' + f
                for f in failed_fixtures if f not in skipped_fixtures
                # and not f.startswith('bugreports_')
                and not f.startswith('collapse_')
                # and not f.startswith('date_')
                and not f.startswith('decorations_')
                and not f.startswith('disambiguate_')
                and not f.startswith('flipflop_')
                and not f.startswith('magic_Name')
                and not f.startswith('name_')
                and not f.startswith('nameattr_')
                and not f.startswith('nameorder_')
                and not f.startswith('number_')
                # and not f.startswith('textcase_')
                ])

for path in paths:
    # print(path)

    with open(path) as f:
        lines = f.readlines()

    xml = ''
    in_xml = False
    for line in lines:
        if re.match(r'>>=+\s*CSL\s*=+>>', line):
            in_xml = True
        elif re.match(r'<<=+\s*CSL\s*=+<<', line):
            break
        elif in_xml:
            xml += line

    root = ET.fromstring(xml)
    tags = []

    for el in root.iter():
        tag = el.tag.split("}")[1]
        tags.append(tag)

    # root = root.getroot()
    count = Counter(tags)

    # file = os.path.split(path)[1]
    num_tags[path] = len(count.items())


# print(num_tags)

for path in list(sorted(paths, key=lambda x: num_tags[x]))[:10]:
    print(f'{num_tags[path]:<4}{os.path.split(path)[1]:50}{path}')

# print(len(failed_fixtures))
