#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys

sys.path.append('includes/')
import common

print(common.facter(['virtual']))
print(common.run_check_if_running_as_vm_imvirt())
