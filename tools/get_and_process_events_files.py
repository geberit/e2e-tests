#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# The code is not part of common.py so that we can use state of the art Python3.
# No, it is not that easy. logstash_async can be tricky to get running on Python3.

"""
Script which can be run via cron to collect a logstash_async events.db file for
injection into Logstash in case the "sending" host can not directly connect to
Logstash.
"""

__license__ = 'AGPL-3.0-only'
__author__ = 'Robin Schneider <robin.schneider@geberit.com>'
__copyright__ = [
    'Copyright (C) 2017-2018 Robin Schneider <robin.schneider@geberit.com>',
    'Copyright (C) 2017-2018 Geberit Verwaltungs GmbH https://www.geberit.de',
]

# Cron example:
# */15 *  * * *    cd /usr/local/share/e2e-tests && python2 ./tools/get_and_process_events_files.py 1>/dev/null

import sys
import subprocess
import os
import glob
import logging

sys.path.append('includes/')
from common import get_config, get_scp_target_dir_path, get_logstash_handler


def get_and_process_events_files():
    config = get_config()

    source_dir_path = get_scp_target_dir_path() + '/'

    spool_path = '/var/spool/e2e-logstash'
    # os.makedirs(spool_path, exist_ok=True)

    subprocess.call([
        'rsync',
        '--archive',
        '--remove-source-files',
        source_dir_path,
        spool_path,
    ], stdout=subprocess.PIPE)

    for f in glob.glob(spool_path + '/*'):
        print(f)

        logstash_handler = get_logstash_handler(config, database_path=f)

        logger = logging.getLogger(__name__)
        logger.addHandler(logstash_handler)

        logstash_handler._start_worker_thread()
        logstash_handler.flush()

        logger.removeHandler(logstash_handler)
        logstash_handler.close()

        os.remove(f)


get_and_process_events_files()
