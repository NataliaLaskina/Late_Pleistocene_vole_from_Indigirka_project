### Rename tree script: `scripts/rename_tree.py`
#!/usr/bin/env python3
"""
Rename tree labels from GenBank accession numbers to readable species names.
Usage: python3 rename_tree.py
"""

import re

# Define input and output files
INPUT_FILE = 'cytb_mcc.tree'  # or your tree file name
OUTPUT_FILE = 'cytb_mcc_named.tree'

# Read tree file
with open(INPUT_FILE, 'r') as f:
    tree = f.read()

# Manual replacements for specific samples
replacements = {
    'GU809130.1': 'M_miurus_Wrangell_Mts_relict',
    'AF163895.1': 'Stenocranius_gregalis',
    'DQ432006.1': 'Microtus_ochrogaster',
    'KF948532.1': 'Microtus_montanus',
    'KF964337.1': 'Microtus_longicaudus',
    'AF163890.1': 'M_abbreviatus_3890',
}

# Apply manual replacements
for old, new in replacements.items():
    tree = tree.replace(old, new)

# Automatic replacement for GU809xxx accessions
def replace_gu(match):
    full_id = match.group(0)
    digits = re.search(r'GU(\d+)\.1', full_id)
    if digits:
        last_4 = digits.group(1)[-4:]
        return f'M_miurus_{last_4}'
    return full_id

tree = re.sub(r'GU\d+\.1', replace_gu, tree)

# Write output
with open(OUTPUT_FILE, 'w') as f:
    f.write(tree)

print(f"Done! Renamed tree saved to {OUTPUT_FILE}")