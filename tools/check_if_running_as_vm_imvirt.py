#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TODO: We are not using this script because the wmi Python package turns out to be not reliable installable.

Needed as standalone script because it only seems to work with Python 3 but
we are bound to Python 2 in ../includes/common.py for now.
Returns with exit code 0 if we run in a VM.

Implementation for other languages: ./check_if_running_as_vm_imvirt.au3
"""

__license__ = 'AGPL-3.0-only'
__author__ = 'Robin Schneider <robin.schneider@geberit.com>'
__copyright__ = [
    'Copyright (C) 2018 Robin Schneider <robin.schneider@geberit.com>',
    'Copyright (C) 2018 Geberit Verwaltungs GmbH https://www.geberit.de',
]

import sys

running_in_vm = False

try:
    import wmi
except ModuleNotFoundError:
    print("Missing dependency. Fallbacking back in assuming that we run in a virtual machine.")
    sys.exit(0)

c = wmi.WMI()
wql = "select Manufacturer,Model from win32_computersystem"
for item in c.query(wql):

    # Check for VMware VM:
    if 'vmware' in item.Manufacturer.lower():
        print("Detected VMware hypervisor.")
        running_in_vm = True
        break

if running_in_vm:
    print("Running as guest on a Hypervisor. We took the blue pill and are inside the matrix.")
else:
    print("Running on bare metal. Welcome to the real world, we took the red pill and escaped the matrix.")

sys.exit(not running_in_vm)
