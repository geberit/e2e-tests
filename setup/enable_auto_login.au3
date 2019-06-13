Opt("MustDeclareVars", 1)

#include-once
#include "../includes/common.au3"

Local $login_credentials = get_login_credentials()
Local $username = StringSplit($login_credentials.Item('username'), '\\', $STR_NOCOUNT)

Local $command = ["autologon", $username[1], $username[0], $login_credentials.Item('password')]

ensure_command_returns_without_errors($command, Default, True)

MsgBox( _
    BitXOR($MB_APPLMODAL, $MB_ICONINFORMATION, $MB_OK), _
    "e2e-tests: Auto login enabled successfully", _
    "Auto login of user " & $login_credentials.Item('username') & _
	" has been enabled successfully." & _
    " This message box will self-destruct in ten seconds.", _
    10)
