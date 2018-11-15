rem M$ hacks. Don’t ask.

setlocal
cd /d %~dp0/..
/Python27/python.exe "tools/process_log_events.py"
