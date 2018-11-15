# -*- coding: utf-8 -*-

"""
Geberit common Python functions used/included in various Python/Sikulix scripts.
Implementation for other languages: common.au3
Functions are implemented lazily (ref: "lazy loading").
"""

__license__ = 'AGPL-3.0-only'
__author__ = 'Robin Schneider <robin.schneider@geberit.com>'
__copyright__ = [
    'Copyright (C) 2016-2018 Robin Schneider <robin.schneider@geberit.com>',
    'Copyright (C) 2016-2018 Geberit Verwaltungs GmbH https://www.geberit.de',
]

import sys
import logging
import os
import glob
import re
import platform
import datetime

# if sys.version_info[0] == 2:
#     import pathlib2 as pathlib
# else:
#     import pathlib

try:
    import json
except:
    import simplejson as json

try:
    from configparser import ConfigParser
except ImportError:
    from ConfigParser import SafeConfigParser as ConfigParser

import subprocess
try:
    from subprocess import DEVNULL
except ImportError:
    DEVNULL = open(os.devnull, 'wb')

try:
    from functools import lru_cache
except ImportError:
    from backports.functools_lru_cache import lru_cache

try:
    import uptime
except:
    pass


def check_output(*popenargs, **kwargs):
    r"""Source: https://gist.github.com/edufelipe/1027906

    Run command with arguments and return its output as a byte string.
    Backported from Python 2.7 as it's implemented as pure python on stdlib.
    >>> check_output(['/usr/bin/python', '--version'])
    Python 2.6.2
    """
    process = subprocess.Popen(stdout=subprocess.PIPE, *popenargs, **kwargs)
    output, unused_err = process.communicate()
    retcode = process.poll()
    if retcode:
        cmd = kwargs.get("args")
        if cmd is None:
            cmd = popenargs[0]
        error = subprocess.CalledProcessError(retcode, cmd)
        error.output = output
        raise error
    return output


def get_java_version():
    java_version_output = check_output(["java", "-version"], stderr=subprocess.STDOUT)
    return java_version_output.splitlines()[0].split()[-1].strip('"')


def get_os_release_id():
    """
    Windows 10 build version (release ID).
    Using os.popen because winreg does not work under SikuliX.

    Ref:https://stackoverflow.com/a/38936997
    """
    key = r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    val = r'ReleaseID'
    output = os.popen('REG QUERY "{0}" /V "{1}"'.format(key, val)).read()
    return output.strip().split(' ')[-1]


def is_running_under_sikulix():
    # We are running under Sikulix.
    # return 'waitVanish' in globals()
    # return 'Env' in globals() and hasattr(Env, 'getSikuliVersion')
    return not (sys.executable and 'python' in sys.executable)


if not is_running_under_sikulix():
    from logstash_async.handler import AsynchronousLogstashHandler
    from logstash_async.formatter import LogstashFormatter

    # Exclude does not work here. We do it in Logstash.
    #  from logstash_async.constants import constants
    #  constants.FORMATTER_RECORD_FIELD_SKIP_LIST.extend([
    #      'func_name', 'interpreter', 'interpreter_version',
    #      'line', 'logsource', 'logstash_async_version',
    #      'pid', 'process_name', 'program', 'thread_name',
    #  ])


def git_working_copy_is_dirty():
    git_wc_dirty_rc = subprocess.call(['git', 'diff-index', '--quiet', 'HEAD', '--'], stdout=DEVNULL)
    if git_wc_dirty_rc == 0:
        return False
    else:
        return True


def merge(a, b, path=None):
    "merges b into a"
    if path is None:
        path = []
    for key in b:
        if key in a:
            if isinstance(a[key], dict) and isinstance(b[key], dict):
                merge(a[key], b[key], path + [str(key)])
            elif a[key] == b[key]:
                pass  # same leaf value
            else:
                raise Exception('Conflict at %s' % '.'.join(path + [str(key)]))
        else:
            a[key] = b[key]
    return a


def get_filename_save_cur_timestamp():
    return str(datetime.datetime.now().isoformat()).replace(":", "_").replace(".", "_")


def get_script_name():
    return os.path.splitext(os.path.basename(sys.argv[0]))[0]


def get_cache_path():
    cache_path = 'c:/var/cache/e2e-tests'
    if not os.path.exists(cache_path):
        os.makedirs(cache_path)

    return cache_path


def get_spool_path():
    spool_path = 'c:/var/spool/e2e-tests'
    if not os.path.exists(spool_path):
        os.makedirs(spool_path)

    return spool_path


def get_working_path():
    working_path = 'c:/var/lib/e2e-tests'
    if not os.path.exists(working_path):
        os.makedirs(working_path)

    return working_path


def get_screenshot_path():
    screenshot_path = get_working_path() + '/screenshots'
    if not os.path.exists(screenshot_path):
        os.makedirs(screenshot_path)

    return screenshot_path


def get_log_path():
    log_path = 'c:/var/log/e2e-tests'
    if not os.path.exists(log_path):
        os.makedirs(log_path)

    return log_path


def get_log_file_path_for_script(suffix="", subdir=False):
    if suffix != "":
        suffix = "_" + suffix

    dir_path = get_log_path()
    if subdir:
        dir_path += "/" + get_script_name() + suffix
        if not os.path.exists(dir_path):
            os.makedirs(dir_path)

        file_base_path = dir_path + '/' + get_filename_save_cur_timestamp()
    else:
        file_base_path = dir_path + '/' + get_script_name() + suffix

    return file_base_path + '.log'


def get_login_credentials_file_path():
    return get_working_path() + "/login_credentials.json"


def get_login_credentials():
    login_credentials_file_path = get_login_credentials_file_path()
    if not os.path.exists(login_credentials_file_path):
        raise Exception(
            "OS user login credentials not found in registry nor in file: " + login_credentials_file_path + "." +
            " The file is written by ./execute-perftest.au3 if the credentials are contained in the Windows registry for auto login." +
            " If not, you need to manually create the file." +
            ' Example content: {"username":"user","password":"pw"}'
        )

    return json.load(open(login_credentials_file_path))


def get_logstash_handler(config, database_path=None):
    if not database_path:
        database_path = get_spool_path() + '/events.db'

    logstash_handler = AsynchronousLogstashHandler(
        config.get('Output', 'logstash_host'),
        config.getint('Output', 'logstash_port'),
        database_path=database_path,
    )
    logstash_handler.formatter = LogstashFormatter(
        # `extra` could be used but we just do it in `get_log_metadata`.
        #  extra={},
        extra_prefix=None,
    )

    return logstash_handler


def get_logger(config, name='python-logstash-logger', database_path=None):
    if is_running_under_sikulix():
        raise NotImplemented("Not working under Sikulix")

    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)

    logger.addHandler(get_logstash_handler(config, database_path=database_path))

    return logger


def get_file_and_stdout_logger():
    logger = logging.getLogger(get_script_name())
    logger.setLevel(logging.DEBUG)

    formatter = logging.Formatter(
        '%(levelname)s, %(asctime)s.%(msecs)03d, %(filename)s:%(lineno)s: %(message)s',
        '%Y-%m-%d %H:%M:%S')

    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    fh = logging.FileHandler(get_log_file_path_for_script())
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(formatter)
    logger.addHandler(fh)

    return logger


def get_log_metadata(custom_data, config, Env=None):
    hostname = platform.node().lower()
    location = hostname[1:5]

    extra = {
        '#pre_filters': ['python-logging'],
        '#source': 'e2e-tests',
        #  'host': platform.node(),
        'env': {
            # Modeled after Ansible facts.
            # Not working. https://stackoverflow.com/questions/3425294/how-to-detect-the-os-default-language-in-python
            # Does not work in SikuliX.
            # 'user_ui_language': locale.windows_locale[ windll.GetUserDefaultUILanguage() ],
            'user_name': os.getenv('username', default=os.getenv('USER')).lower(),
            'location_id': location,
            'managed_network': config.getboolean('Environment', 'managed_network'),
            'managed_software': config.getboolean('Environment', 'managed_software'),
            'custom': '',
        },
        'meta': {
            'monitoring': False,
            'uncommited_changes': True,
        },
    }

    if is_running_under_sikulix():
        # Not needed.
        extra['env'].update({
           'os_family': 'Microsoft ' + str(Env.getOS()).capitalize(),
           'distribution': str(Env.getOS()).capitalize(),
           'distribution_major_version': str(Env.getOSVersion()),
           'distribution_full_name': str(Env.getOS()).capitalize() + " " + Env.getOSVersion(),
           'distribution_release_id': get_os_release_id(),

        })
    else:
        extra['env'].update({
           'os_family': 'Microsoft ' + str(platform.system()),
           'distribution': str(platform.system()),
           'distribution_major_version': str(platform.release()),
           'distribution_full_name': platform.system() + " " + platform.release(),
           'distribution_release_id': get_os_release_id(),
           'virtual_machine': run_check_if_running_as_vm_imvirt(),
        })

    if 'uptime' in globals():
        # Ref: ansible_uptime_seconds in Ansible facts
        # We use "uptime" as field name because Kibana can make seconds human
        # readable and that it looks odd if the field is called
        # "uptime_seconds" but it is shown as a different unit.
        extra['env'].update({
           'uptime': int(uptime.uptime())
        })

    try:
        extra['meta']['commit_hash'] = subprocess.Popen(
         ["git", "rev-parse", "--short", "HEAD"],
         stdout=subprocess.PIPE,
        ).communicate()[0].strip()
        # extra['meta']['uncommited_changes'] = git_working_copy_is_dirty()
        # FIXME: Does not work
    except OSError:
        pass

    # uncommited_changes means dirty working copy which means we are
    # developing which means -> staging
    if 'production' == config.get('Environment', 'tier').lower():
        extra['meta']['uncommited_changes'] = False

    if config.has_option('Environment', 'custom_text'):
        extra['env']['custom'] = config.get('Environment', 'custom_text')

    if config.has_option('Environment', 'location_id'):
        extra['env']['location_id'] = config.get('Environment', 'location_id')

    if config.has_option('Meta', 'monitoring'):
        extra['meta']['monitoring'] = config.getboolean('Meta', 'monitoring')

    merge(extra, custom_data)
    return extra


# def get_windows_path(path):
#     return pathlib.PureWindowsPath(path)


def store_log_event(level, msg, extra=None):
    if not extra:
        extra = {}

    extra.setdefault('meta', {})['test'] = get_script_name()

    spool_obj = {
        'level': level,
        'msg': msg,
        'extra': extra,
    }

    spool_file = get_spool_path() + '/' + get_filename_save_cur_timestamp() + '.json'
    spool_fh = open(spool_file, 'w')
    # with open(spool_file, 'w') as spool_fh:
    json.dump(spool_obj, spool_fh)
    spool_fh.close()


def process_log_events():
    config = get_config()
    logger = get_logger(config)

    log_function_map = {
        'critical': logger.critical,
        'error': logger.error,
        'warn': logger.warn,
        'warning': logger.warning,
        'info': logger.info,
        'debug': logger.debug,
    }

    for spool_file in glob.glob(get_spool_path() + '/*.json'):
        #  print(spool_file)
        spool_fh = open(spool_file, 'r')
        # with open(spool_file, 'r') as spool_fh:
        spool_obj = json.load(spool_fh)
        spool_obj['extra'] = get_log_metadata(spool_obj['extra'], config)
        print(spool_obj)
        log_function_map[spool_obj['level']](
            spool_obj['msg'],
            extra=spool_obj['extra'],
        )
        spool_fh.close()
        os.unlink(spool_file)


def get_scp_target_dir_path():
    config = get_config()

    return '%s@%s:%s' % (
        config.get('Output', 'logstash_via_scp_user'),
        config.get('Output', 'logstash_via_scp_host'),
        config.get('Output', 'logstash_via_scp_path'),
    )


def scp_log_events():
    config = get_config()
    source_file = get_spool_path() + '/events.db'

    if config.getboolean('Output', 'logstash_via_scp') and os.path.exists(source_file):
        hostname = platform.node().lower()
        timestamp = get_filename_save_cur_timestamp()
        target_filename = '%s_%s_events.db' % (hostname, timestamp)

        scp_target = '%s/%s' % (
            get_scp_target_dir_path(),
            target_filename,
        )

        # We do not have rsync.
        # Getting the return code of `scp` through `git-bash.exe` does not work, doing `rm` in bash.
        subprocess.call([
           '/Program Files/Git/git-bash.exe',
           '-c', 'scp "%s" "%s" && rm "%s"' % (source_file, scp_target, source_file),
        ], stdout=subprocess.PIPE)


def get_config(config_file='./perf.ini'):
    config_file = ConfigParser(defaults={
        'syslog': 'False',
        'csv': 'False',
        'logstash': 'False',
        'managed_network': 'True',
        'managed_software': 'True',
    })
    config_file.read('./perf.ini')

    return config_file


def delete_files_in_dir(dir_path):
    for f in glob.glob(dir_path + '/*'):
        os.remove(f)


def get_python_install_dir_path(py_version=3):
    return glob.glob('c:/Python' + str(py_version) + '*')[0]


def run_process_log_events():
    py_inst_dir_path = get_python_install_dir_path(py_version=2)
    subprocess.call([py_inst_dir_path + '/python.exe', './tools/process_log_events.py'], stdout=subprocess.PIPE)
    subprocess.call([py_inst_dir_path + '/python.exe', './tools/scp_log_events.py'], stdout=subprocess.PIPE)


def run_check_if_process_is_running(exe):
    py_inst_dir_path = get_python_install_dir_path(py_version=2)
    return not subprocess.call([py_inst_dir_path + '/python.exe', './tools/check_if_process_is_running.py', exe], stdout=DEVNULL)


@lru_cache(maxsize=32)
def run_check_if_process_is_running_cached(exe):
    return run_check_if_process_is_running(exe)


def run_check_if_running_as_vm_imvirt():
    return not subprocess.call([
        'c:/Program Files (x86)/AutoIt3/autoit3.exe',
        '/AutoIt3ExecuteScript',
        './tools/check_if_running_as_vm_imvirt.au3'
    ], stdout=DEVNULL)


def get_enabled_processes_as_set(e2e_test):
    enabled_process_names = set()
    config = get_config()

    for enabled_process in config.get(e2e_test, 'enabled_processes').split('\n'):

        if not enabled_process or re.search(r'\s[#;]', enabled_process):
            continue

        enabled_process = enabled_process.strip()

        # Deprecated format:
        enabled_process = re.sub(r'^run_process_', '', enabled_process)

        enabled_process_names.add(enabled_process)

    return enabled_process_names
