# Does not work on Windows 7

Register-ScheduledTask -Xml (get-content 'cron-e2e.xml' | out-string) -TaskName E2E
