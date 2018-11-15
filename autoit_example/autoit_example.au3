Opt("MustDeclareVars", 1)

#include "../includes/common.au3"
#include "../includes/log4a.au3"

enable_logging()


Local $latencies = ObjCreate("Scripting.Dictionary")

Local $e2e_metrics = ObjCreate("Scripting.Dictionary")
store_log_event("info", "AutoIt test workflow completed sucessfully", $e2e_metrics)
run_process_log_events()