# e2e-tests skeleton and modules

This repository contains templates, modules and helper scripts for E2E testing/monitoring using SikuliX in Python and AutoIt. No finished E2E tests are contained because they are too customized to the (proprietary) application and test data.

The metrics are send to the Elastic stack for further analysis. Logstash can be used to also send metrics to a Monitoring system to do alerting based on thresholds.

Note that both Python on Windows in SikuliX and AutoIt have limitations. You will find some calls from SikuliX to a standalone Python script and calls from AutoIt to Python. This was done to work around such limitations. It might not be beautiful but it works. Also note that we are currently bound to Python 2 because some Python dependencies did not install properly in a Python 3 environment on Windows and also, SikuliX as of 1.1.3 only has Python 2.7 embedded. The code is already Python 3 compatible where possible.

## Logstash output format

Every single test is represented as a list of key-value pairs in one document in Elasticsearch. The important keys are:

* `@timestamp`: Timestamp added by the Monitoring probe when the test is done. Does not have to be the same as the submit time because the Logstash output supports caching/is fault tolerant.
* `host`: Name of the Monitoring probe.
* `severity`: 6 means all processes passed: It was possible to finish the workflow until the end and all metrics are present in the test result. 4 means one or more processes failed: Metrics are only available up until a processed failed. 3 means that an issue in the init phase of the test occurred so no metrics are available.
* `msg`: Text summary of `severity`.
* `exception_short`: List of exceptions which occurred in the form of a stack trace. A stack trace represents the function call history which lead to an exception. The format is: "Line number, surrounding function, code line". The stack trace is read from left to right meaning that the most right function call is the depest one where the actual issue occurred.
* `tags`: Optional tags which are used to signal special events of the test run. For example, the need to login, or some warning that was shown and we clicked the "Go away warning" button.
* `data.*` under which all measurements (unit is duration in seconds) are saved.
* `env.*` contains infos about the Monitoring probe like OS, network, VM.
* `meta.*` contains infos about the test itself. For example, `meta.commit_hash` contains the exact version number of the E2E test. Meaning that metrics and the exact test implementation they where measured with are tied together. If something is fix/change, it will be visible as the `meta.commit_hash` changing.

## Logstash filter config

Refer to: https://github.com/geberit/logstash-config-integration-testing/tree/master/examples/e2e-tests

### AutoIt

SciTE as editor is helpful. F1 brings up a help containing references and syntax of AutoIt.

Ensure SciTE is configured as follows (Options -> Open User Options File):

```INI
use.tabs=0
indent.size=4
indent.size.*.au3=4
tabsize=4
```

And restart SciTE if you changed it.

### SikuliX

SikuliX scripts can be interrupted using Shift+Alt-C.

Because SikuliX works with image recognition, it can be very sensitive to slight deviations. Common issues:

* Display resolution
* Font rendering
* Browser zoom level! (Seems the default on Windows 7 is 125% zoom, while on Windows 10 it is 100%)

## Dependencies

Refer to: `./setup/bootstrapper.ps1`.

## AutoIt dependencies

External libraries are not bundled in this repo because of unclear licensing. Download and extract the following to `./includes/`:

* `ProcessGetExitcode.au3`: https://www.autoitscript.com/forum/topic/23096-exitcode-from-run/
* `Json.au3`: https://www.autoitscript.com/forum/topic/148114-a-non-strict-json-udf-jsmn/
* `log4a.au3`: https://www.autoitscript.com/forum/topic/156196-log4a-a-logging-udf/

  You might want to use a different timestamp format by replacing the `StringFormat` calls and use
  `get_current_date_as_rfc_3339_string()` instead.

## License

[AGPL-3.0-only](https://www.gnu.org/licenses/agpl-3.0.html)

* Author Copyright (C) 2016-2018 Robin Schneider
* Company Copyright (C) 2016-2018 [Geberit Verwaltungs GmbH](https://www.geberit.de)
