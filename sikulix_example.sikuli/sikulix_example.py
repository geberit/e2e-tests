# -*- coding: utf-8 -*-

"""
Tested against $our_target_software
Version: $version
Last checked: $date
(Version can be shown by clicking on the account picture in the top right corner and then "Info" -> "Version")
"""

__license__ = 'AGPL-3.0-only'
__author__ = 'Robin Schneider <robin.schneider@geberit.com>'
__copyright__ = [
    'Copyright (C) 2016-2018 Robin Schneider <robin.schneider@geberit.com>',
    'Copyright (C) 2016-2018 Geberit Verwaltungs GmbH https://www.geberit.de',
]

import os
import re
import sys
import traceback
import logging

if "c:\python27\lib\site-packages" not in sys.path:
    sys.path.append("c:\python27\lib\site-packages")
sys.path.append('c:\python27\lib')

sys.path.append(os.sep.join([os.path.dirname(getBundlePath()), "includes"]))


import common
reload(common)

import sikulix_common
reload(sikulix_common)
# Never do this or dragons eat you when you sleep/`wait()` (as of SikuliX 1.1.3):
# from sikulix_common import *

# common.get_config() tries to load the configuration from inside the e2e-tests repo.
os.chdir(getBundlePath() + '/..')

logger = common.get_file_and_stdout_logger()

# Unsure why but SikuliX does not seem to use the Python logging module.
Settings.LogTime = True
Settings.DebugLogs = True

# Debug.setLogFile would overwrite an existing file thus we include a timestamp in the filename.
Debug.setLogFile(common.get_log_file_path_for_script(suffix='sikulix', subdir=True))

e2e_metrics = {}
report_tags = set()


def save_metric(metric_name, metric_value, iteration_count):
    metric_full_name = metric_name + '_' + str(iteration_count)

    logger.debug(metric_full_name + ": " + str(metric_value))

    e2e_metrics[metric_full_name] = metric_value

    return metric_full_name


def run_process_x(iteration_count, recursion_depth=0):
    process_time = 0

    # click()

    start_subprocess_time = sikulix_common.start_time_measurement()
    # wait()
    sleep(1)

    response_time = sikulix_common.stop_time_measurement(start_subprocess_time)
    process_time += response_time
    save_metric("e2e-sikulix_example-x-01-load_form_XX-response_time", response_time, iteration_count)
    save_metric("e2e-sikulix_example-x-process_time", process_time, iteration_count)


def run_process_init(iteration_count, recursion_depth=0):
    # Ensure time measurement signal is set to stopped.
    # Also required to warm up lru_cache to not have any (noticeable) delay later.
    sikulix_common.stop_time_measurement(0)

    sikulix_common.start_screen_recording()

    # Start application and ensure that zoom/settings are as we expect them.


def main():
    config = common.get_config()

    setAutoWaitTimeout(60)

    enabled_process_names = common.get_enabled_processes_as_set('sikulix_example')
    enabled_process_names.add('init')
    logger.debug(enabled_process_names)

    log_event_severity = 'info'
    log_event_msg = 'sikulix_example SikuliX test workflow completed successfully'
    exceptions = []
    exception_short = []

    # Only one iteration -> How does caching behave is not tested.
    for iteration_count in [1]:

        # Needed to define the order.
        supported_processes = [
            run_process_init,
            run_process_x,
        ]

        for supported_process in supported_processes:
            supported_process_name = re.sub(r'^run_process_', '', supported_process.__name__)
            if supported_process_name not in enabled_process_names:
                continue

            try:
                logger.info("Run " + supported_process_name + ".")
                supported_process(iteration_count)
                logger.info(supported_process_name + " completed successfully.")

            # FindFailed does not inherit from Exception!!!
            except (Exception, FindFailed):
                log_event_severity = 'warn'

                logger.warn(supported_process_name + " failed.")

                logger.exception(traceback.format_exc().strip())
                exceptions.append(traceback.format_exc().strip())

                exception_short_tmp = []
                for x in traceback.extract_tb(sys.exc_info()[2]):
                    if not x[3].startswith("supported_process"):
                        exception_short_tmp.append(str(x[1]) + ': ' + str(x[2]) + ': ' + str(x[3]))
                exception_short.append('\n'.join(exception_short_tmp))

                try:
                    sikulix_common.take_screenshot()
                except:
                    report_tags.add('e2e-sikulix_example-unable_to_take_screenshot')

                if supported_process_name == 'init':
                    log_event_severity = 'error'
                    log_event_msg = 'sikulix_example SikuliX test workflow failed'
                    # We can not continue with the processes.
                    break

    if config.getboolean('Output', 'logstash'):
        common.store_log_event(
            log_event_severity,
            log_event_msg,
            extra={
                'tags': list(report_tags),
                'meta': {
                    'engine_name': Env.getSikuliVersion().split()[0],
                    'sikulix_version': Env.getSikuliVersion().split()[1],
                    'java_version': common.get_java_version(),
                    'km_processes': list(enabled_process_names),
                },
                'data': e2e_metrics,
                'exception': exceptions,
                'exception_short': exception_short,
            },
        )
        common.run_process_log_events()

    # Needed because the SikuliX GUI reuses the same interpreter for multiple runs.
    logging.shutdown()

    sikulix_common.stop_screen_recording()

    sys.exit({'error': 1}.get(log_event_severity, 0))


main()
