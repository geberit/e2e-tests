# -*- coding: utf-8 -*-

"""
Generic SikuliX related Python functions used/included in various Sikulix scripts.

Never do this or dragons eat you when you sleep/`wait()` (as of SikuliX 1.1.3):
from sikulix_common import *
For example, the next wait after waitMultiple was called will not find it’s
image although the image was visible and SikulixIDE found it.
"""

__license__ = 'AGPL-3.0-only'
__author__ = 'Robin Schneider <robin.schneider@geberit.com>'
__copyright__ = [
    'Copyright (C) 2016-2018 Robin Schneider <robin.schneider@geberit.com>',
    'Copyright (C) 2016-2018 Geberit Verwaltungs GmbH https://www.geberit.de',
]

import time
import logging
import shutil
import types

from sikuli import *

import common

logger = logging.getLogger(__name__)


def take_screenshot():
    # As of 1.1.2, capture is supposed to support SCREEN.capture(SCREEN,
    # 'path', 'filename').getFile() but it does not work as of 1.1.3.
    file_path = SCREEN.capture().getFile()

    screenshot_file_path = common.get_screenshot_path() + '/' + common.get_filename_save_cur_timestamp() + '.png'
    shutil.move(file_path, screenshot_file_path)


# Useful for debugging and transparency when communicating with CRM team.
# This is a side effect of my work on the neo-vars AutoHotKey script.
# Run ../tools/show_time_measure_tray_icon.ahk before.
def start_time_measurement():
    start_measurement_time = time.time()

    show_time_measure_tray_icon_is_running = common.run_check_if_process_is_running_cached('show_time_measure_tray_icon')

    if show_time_measure_tray_icon_is_running:
        type("I", KeyModifier.WIN)
    return start_measurement_time

def stop_time_measurement(start_time):
    measurement_duration = time.time() - start_time

    show_time_measure_tray_icon_is_running = common.run_check_if_process_is_running_cached('show_time_measure_tray_icon')

    if show_time_measure_tray_icon_is_running:
        type("O", KeyModifier.WIN)
    return measurement_duration


## Start screen recording using OBS Studio.
def start_screen_recording():
    obs_studio_is_running = common.run_check_if_process_is_running_cached('obs-studio')

    if obs_studio_is_running:
        sleep(1)
        logger.debug("Start screen recording.")
        type("C", KeyModifier.WIN)
        sleep(1)

def stop_screen_recording():
    obs_studio_is_running = common.run_check_if_process_is_running_cached('obs-studio')

    if obs_studio_is_running:
        sleep(1)
        logger.debug("Stop screen recording.")
        type("C", KeyModifier.WIN)
        sleep(1)


def waitMultiple(patterns, wait_timeout):
    found_pattern = False

    # Image recognison takes a bit.
    timeout_for_pattern = 0.1
    # 0.9 is based on testing on a slow Windows 7 client with 30 iterations.
    duration_of_iteration = len(patterns) * (timeout_for_pattern + 0.9)

    number_of_iterations = int(wait_timeout / duration_of_iteration)
    logger.debug("waitMultiple will run for " + str(number_of_iterations) + " iterations")
    for _ in range(1, number_of_iterations):
        logger.debug("waitMultiple iteration: " + str(_))
        for pattern in patterns:
            if exists(pattern, timeout_for_pattern):
                found_pattern = pattern
                break

        if found_pattern:
            break

        sleep(0.25)

    if not found_pattern:
        # Seems we can not easily raise a real FindFailed exception.
        raise Exception("Custom FindFailed exception: waitMultiple did not find any of the patterns.")

    logger.debug("waitMultiple found_pattern: " + str(found_pattern))
    return found_pattern


# TODO: Implement, run_action_sequence(actions, repeat_count=15, sleep_seconds=1)
# `actions` example [Pattern(), [Pattern(), Pattern()], Pattern()]
# Run all actions in sequence. If one fails, start from the beginning.


def actionUntilExists(action, pattern, repeat_count=15, sleep_seconds=1, click_on_exists=False):
    """
       Execute `action` until `pattern` appears.
       If `action` is a pattern, we click it.
    """

    appeared = False
    for iteration in range(repeat_count):
        if exists(pattern, 0.1):
            appeared = True
            break
        elif isinstance(action, types.FunctionType):
            action(iteration=iteration)
        else:
            click(action)

        sleep(sleep_seconds)

    if appeared:
        if click_on_exists:
            return click(pattern)
        else:
            return pattern
    else:
        raise Exception("Endless loop in actionUntilExists.")


def clickWhileExists(pattern, repeat_count=15, sleep_seconds=1, action_function=None):
    """Click on `pattern` or execute `action_function` until `pattern` disappears."""

    vanished = False
    for iteration in range(repeat_count):
        if iteration != 0:
            sleep(sleep_seconds)

        if exists(pattern, 0.1):
            if action_function:
                action_function(iteration=iteration)
            else:
                click(pattern)
        else:
            logger.debug(str(pattern) + " vanished")
            vanished = True
            break

    if vanished:
        return pattern
    else:
        raise Exception("Endless loop while clickling.")
