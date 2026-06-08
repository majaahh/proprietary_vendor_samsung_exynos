#!/usr/bin/env python3
#
# SPDX-FileCopyrightText: Majaahh
# SPDX-License-Identifier: Apache-2.0
#

import sys
from collections import defaultdict

models = defaultdict(list)

args = sys.argv[1:]

if args:
    if len(args) % 2:
        sys.exit("Arguments must be MODEL CSC pairs")

    for model, csc in zip(args[::2], args[1::2]):
        models[model].append(csc)
else:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        model, csc = line.split()
        models[model].append(csc)

for model, cscs in models.items():
    quoted = ", ".join(f'"{c}"' for c in cscs)
    print(f'"{model}": [{quoted}],')
