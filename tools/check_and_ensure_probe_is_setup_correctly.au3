Opt("MustDeclareVars", 1)

#include-once
#include <MsgBoxConstants.au3>

#include "../includes/common.au3"

check_and_ensure_probe_is_setup_correctly()
get_config_file_path()

MsgBox( _
    BitXOR($MB_APPLMODAL, $MB_ICONINFORMATION, $MB_OK), _
    "e2e-tests: Everything is in perfect order", _
    "All checks passed. The probe should be setup correctly. This message box will self-destruct in ten seconds.", _
    10)
