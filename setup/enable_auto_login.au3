Opt("MustDeclareVars", 1)

#include "../../includes/common.au3"

Local $login_credentials = get_login_credentials()
Local $username = StringSplit($login_credentials.Item('username'), '\\', $STR_NOCOUNT)

Local $arr = ["autologon", $username[1], $username[0], $login_credentials.Item('password')]


_ArrayDisplay($arr)
ensure_command_returns_without_errors($arr, Default, True)

_ArrayDisplay($arr)
