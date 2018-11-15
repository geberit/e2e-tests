#!/usr/bin/env python2
# -*- coding: utf-8 -*-

import sys

sys.path.append('includes/')
import common


common.store_log_event(
    'info',
    'test',
    extra={
        '@metadata': {
            'pre_filters': ['python-logging'],
        },
        '#source': 'e2e-checklog',
        #  'host': platform.node(),
    },
)
