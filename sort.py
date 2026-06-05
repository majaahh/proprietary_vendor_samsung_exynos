#
# SPDX-FileCopyrightText: Majaahh
# SPDX-License-Identifier: Apache-2.0
#

import json

with open("devices.json") as f:
    data = json.load(f)

with open("devices.json", "w") as f:
    f.write("{\n")

    items = sorted(data.items())

    for i, (k, v) in enumerate(items):
        comma = "," if i < len(items) - 1 else ""
        f.write(f'  "{k}": {json.dumps(v)}{comma}\n')

    f.write("}\n")
