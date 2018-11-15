#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Needed as standalone script because from SikuliX we don’t have access to the
running processes.
"""

__license__ = 'AGPL-3.0-only'
__author__ = 'Robin Schneider <robin.schneider@geberit.com>'
__copyright__ = [
    'Copyright (C) 2018 Robin Schneider <robin.schneider@geberit.com>',
    'Copyright (C) 2018 Geberit Verwaltungs GmbH https://www.geberit.de',
]

import sys
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("search")
args = parser.parse_args()

found_ps = False

try:
    import psutil
except ModuleNotFoundError:
    # Workaround in case dependency is not installed we expect that this is not
    # a dev system.
    sys.exit(1)

for p in psutil.process_iter(attrs=["name", "exe", "cmdline"]):
    if 'python' in p.name():
        # Filter out our own process.
        continue

    try:
        # print(p.as_dict())
        if args.search in p.exe():
            found_ps = True
            break

        for cmd_part in p.cmdline():
            if args.search in cmd_part:
                found_ps = True
                break

    except psutil._exceptions.AccessDenied:
        pass

print("Found: " + str(found_ps))
sys.exit(not found_ps)
