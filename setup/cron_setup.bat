@echo off
rem Works also on Windows 7

schtasks.exe /Create /XML cron-e2e.xml /tn E2E
