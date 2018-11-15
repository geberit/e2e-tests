#cs ----------------------------------------------------------------------------

   @author Copyright (C) 2016-2018 Robin Schneider <robin.schneider@geberit.com>
   @company Copyright (C) 2016-2018 Geberit Verwaltungs GmbH https://www.geberit.de
   @license AGPL-3.0-only <https://www.gnu.org/licenses/agpl-3.0.html>

   Geberit common AutoIt functions used/included in various AutoIt scripts.
   Implementation for other languages: common.py
   Functions are implemented lazily (ref: "lazy loading").

#ce ----------------------------------------------------------------------------

#include-once

#include <MsgBoxConstants.au3>
#include <Date.au3>
#include <File.au3>
#include <FileConstants.au3>
#include <WinAPI.au3>
#include <Misc.au3>
#include <ScreenCapture.au3>
#include <APIConstants.au3>
#include <WinAPIEx.au3>

#include "log4a.au3"
#Include "json/Json.au3"

#Include "python_compatibility_layer.au3"

; Opt("MustDeclareVars", 1)


Func assert_autoit_version_requirement_is_met($required_version, $reason)
    If _VersionCompare($required_version, @AutoItVersion) = 1 Then
        raise(DependencyNotFoundError, _
            "AutoIt version " & $required_version & " is required but version " & @AutoItVersion & " is installed." & _
            $reason)
    EndIf
EndFunc
assert_autoit_version_requirement_is_met("3.3.14.5", _
    " We require $PATH_FILENAME and other constants to be defined in `FileConstants.au3` which is only the case in 3.3.14.5 and above." & _
    " Please upgrade AutoIt.")


Func assert_dependency_command_returns_without_errors($args)
    If Not subprocess_call($args, Default, True) = 0 Then
        raise(DependencyNotFoundError, _
            "The function assert_dependency_command_returns_without_errors was called which ensures that external dependencies are present as early as possible." & _
            " This check failed for the command: `" & _ArrayToString($args, " ") & "`." & _
            " Ensure that the command exits with 0 and try again. Refer to ./setup/.")
    EndIf
EndFunc


Func ensure_command_returns_without_errors($args, $show_flag=Default, $shell=False)
    If Not subprocess_call($args, $show_flag, $shell) = 0 Then
        raise(Exception, _
            "The function ensure_command_returns_without_errors was called with the command: `" & _ArrayToString($args, " ") & "`." & _
            " Ensure that the command exits with 0 and try again.")
    EndIf
EndFunc


Func get_active_window_class()
    Return _WinAPI_GetClassName(WinGetHandle("[ACTIVE]"))
EndFunc


Func write_as_json_file($object, $file_path)
    Local $encoded_json = Json_Encode($object)

    FileDelete($file_path)
    If Not FileWrite($file_path, $encoded_json & @CRLF) Then
        raise(OSError, "An error occurred whilst writing the file: " & $file_path)
    EndIf

    Return True
EndFunc


Func read_as_json_file($file_path)
    Local Const $file_content = FileRead($file_path)
    If Not @error = 0 Then
        raise(OSError, "An error occurred whilst reading the file: " & $file_path)
    EndIf

    Return Json_Decode($file_content)
EndFunc


Func _getDOSOutput($command)
    Local $text = '', $Pid = Run('"' & @ComSpec & '" /c ' & $command, '', @SW_HIDE, 2 + 4)
    While 1
        $text &= StdoutRead($Pid, False, False)
        If @error Then ExitLoop
        Sleep(10)
    WEnd
    Return StringStripWS($text, 7)
 EndFunc   ;==>_getDOSOutput


;; https://www.autoitscript.com/forum/topic/135203-call-another-script/#comment-943199
Func _RunAU3($sFilePath, $sWorkingDir = "", $iShowFlag = @SW_SHOW, $iOptFlag = 0)
   Return Run('"' & @AutoItExe & '" /AutoIt3ExecuteScript "' & $sFilePath & '"', $sWorkingDir, $iShowFlag, $iOptFlag)
EndFunc   ;==>_RunAU3


assert_dependency_command_returns_without_errors(StringSplit("openssl version", ' ', $STR_NOCOUNT))
Func create_random_file($file_path, $size_byte)
    _log4a_Trace("Creating file with random content using OpenSSL of " & get_human_readable_size_for_bytes($size_byte) & " at " & $file_path & ".")

    Local $args = ["openssl", "rand", "-out", $file_path, $size_byte]
    Local $exit_code = subprocess_call($args)
    If Not $exit_code = 0 Then
        raise(OSError, "Could not create random file. OpenSSL exited with " & $exit_code & '.')
    EndIf

    _log4a_Trace("Successfully created the file.")
    Return 1
EndFunc


;; https://www.autoitscript.com/autoit3/docs/functions/FileGetSize.htm
Func get_human_readable_size_for_bytes($value)
    ;; https://en.wikipedia.org/wiki/Binary_prefix#IEC_prefixes
    Local Const $binary_unit_symbols = ['bytes', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB']

    Local $binary_unit_index = 0
    While $value > 1023
        $binary_unit_index += 1
        $value /= 1024
    WEnd
    Return Round($value, 2) & " " & $binary_unit_symbols[$binary_unit_index]
EndFunc


;; Based on get_human_readable_size_for_bytes.
Func get_human_readable_duration_for_ms($value)
    ; Local Const $duration_unit_simbols = ['ms', 's', 'm', 'h', 'd', 'w', 'y']
    Local Const $duration_unit_simbols = ['ms', 's', 'm', 'h']

    Local $duration_unit_index = 0

    If $value > 999 Then
        $duration_unit_index += 1
        $value /= 1000

        While $value > 59 and $duration_unit_index < 3
            $duration_unit_index += 1
            $value /= 60
        WEnd
    EndIf

    Return Round($value, 2) & " " & $duration_unit_simbols[$duration_unit_index]
EndFunc


Func get_filename_save_cur_timestamp()
    Return @YEAR & "-" & @MON & "-" & @MDAY & "_" & @HOUR & "_" & @MIN & "_" & @SEC & "_" & @MSEC
EndFunc


Func get_current_date_as_rfc_3339_string()
    Return @YEAR & "-" & @MON & "-" & @MDAY
EndFunc


Func get_current_datetime_as_rfc_3339_string()
    Local $tz_info = _Date_Time_GetTimeZoneInformation()

    ;; Just for the protocol, the reason this code exists is not because AutoIt sucks but because the holy Windows API GetTimeZoneInformation is stupid.
    Local $utc_offset_in_min = ($tz_info[1] + _Iif($tz_info[0] = 2, $tz_info[7], 0)) * -1
    Local $utc_offset_hours = int($utc_offset_in_min / 60)
    Local $utc_offset_mins = Abs(Mod($utc_offset_in_min, 60))
    Local $utc_offset = StringFormat("%+03d:%02d", $utc_offset_hours, $utc_offset_mins)

    Return get_current_date_as_rfc_3339_string() & " " & @HOUR & ":" & @MIN & ":" & @SEC & "." & @MSEC & $utc_offset
EndFunc


;; https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard
;; Note that the Filesystem Hierarchy Standard (FHS) is not common on Windows, we use it anyway because Windows has nothing appropriate.
Func get_cache_path()
    Local Const $cache_path = 'c:/var/cache/e2e-tests'

    os_makedirs($cache_path)

    Return $cache_path
EndFunc


Func get_spool_path()
    Local Const $spool_path = 'c:/var/spool/e2e-tests'

    os_makedirs($spool_path)

    Return $spool_path
EndFunc


Func get_working_path()
    Local Const $working_path = 'c:/var/lib/e2e-tests'

    os_makedirs($working_path)

    Return $working_path
EndFunc


Func get_screenshot_path()
    Local Const $screenshot_path = get_working_path() & "/screenshots"

    os_makedirs($screenshot_path)

    Return $screenshot_path
EndFunc


Func make_Screenshoot()
    Local Const $screenshot_path = get_screenshot_path()
    os_makedirs($screenshot_path)
    Local $file_name_save_timestamp = get_filename_save_cur_timestamp() & ".jpg"
    _ScreenCapture_Capture($screenshot_path & "/" & $file_name_save_timestamp, 0, 0, @DesktopWidth, @DesktopHeight)
    ; Undeclared variable error.
    ; If @error Then logfile($log_file, $name & "	" & $service & "	" & "ERROR" & "	" & "No Screenshot was possible ")
EndFunc


;; Similar of what os.path.splitext('test.de')[0] would do.
;; We prefer AutoIt here because it has _PathSplit which does more than os.path.splitext.
Func get_file_name_without_extension($file_path)
    Return _PathSplit($file_path, null, null, null, null)[$PATH_FILENAME]
EndFunc


Func get_file_name_with_extension($file_path)
    Local $path_components = _PathSplit($file_path, null, null, null, null)
    Return $path_components[$PATH_FILENAME] & $path_components[$PATH_EXTENSION]
EndFunc


Func get_script_name()
    Return get_file_name_without_extension(@ScriptName)
EndFunc


Func get_working_path_for_script()
    Local Const $working_path_for_check = get_working_path() & "/" & get_script_name()

    os_makedirs($working_path_for_check)

    Return $working_path_for_check
EndFunc


Func get_login_credentials_file_path()
	Return get_working_path() & "/login_credentials.json"
EndFunc


Func get_login_credentials($force_registry=False)
    Local Const $login_credentials_file_path = get_login_credentials_file_path()

    Local $login_credentials = ObjCreate("Scripting.Dictionary")

    If $force_registry Or Not FileExists($login_credentials_file_path) Then
        $login_credentials.Item('username') = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "DefaultUserName")
        $login_credentials.Item('password') = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", "DefaultPassword")
    Else
        $login_credentials = read_as_json_file($login_credentials_file_path)
    EndIf

    If $login_credentials.Item("username") = "" Or $login_credentials.Item("password") = "" Then
        raise(Exception, "OS user login credentials not found in registry nor in file: " & $login_credentials_file_path & "." _
            & " The file is written by ./execute-perftest.au3 if the credentials are contained in the Windows registry for auto login." _
            & " If not, you need to manually create the file." _
            & ' Example content: {"username":"user","password":"pw"}')
    EndIf

	Return $login_credentials
EndFunc


Func write_login_credentials_from_registry_to_file()
    Local Const $login_credentials_file_path = get_login_credentials_file_path()

    ;; We don’t want to touch the file if it already exists to allow to manually create/change it.
    If Not FileExists($login_credentials_file_path) Then
        write_as_json_file(get_login_credentials(True), $login_credentials_file_path)
    EndIf
EndFunc


Func get_log_path()
    Local Const $log_path = 'c:/var/log/e2e-tests'

    os_makedirs($log_path)

    Return $log_path
EndFunc


Func get_log_file_path_for_script($suffix = "")
    If Not $suffix = "" Then
        $suffix = "_" & $suffix
    EndIf

    Return get_log_path() & '/' & get_script_name() & $suffix & '.log'
EndFunc


Func enable_logging()
    _log4a_SetFormat("${date}, ${level}: ${message}")

    _log4a_SetLogFile(get_log_file_path_for_script())
    ; _log4a_SetOutput($LOG4A_OUTPUT_BOTH)
    _log4a_SetEnable()
EndFunc


Func log_message_examples()
    _log4a_Trace("A TRACE message")
    _log4a_Debug("A DEBUG message")
    _log4a_Info("A INFO message")
    _log4a_Warn("A WARN message")
    _log4a_Error("A ERROR message")
    _log4a_Fatal("A FATAL message")
EndFunc


;; Windows has become permissive enough to accept forward slashes as directory separator.
;; Seems some AutoIt functions don’t fully work with normal slashes yet.
;; Also, some legacy Windows applications like the Windows Explorer are known to have issues with it.
;; Use this function for such cases so that we can still use unified file paths which work on all modern platforms everywhere.
Func get_windows_path($path)
    Local $path_components = _PathSplit($path, null, null, null, null)

    $path_components[$PATH_DIRECTORY] = StringReplace($path_components[$PATH_DIRECTORY], "/", "\")

    Return _PathMake($path_components[1], $path_components[2], $path_components[3], $path_components[4])
EndFunc


Func store_log_event($level, $msg, $extra)
    Local $meta = ObjCreate("Scripting.Dictionary")
    $meta.Item('test') = get_script_name()
    $meta.Item('engine_name') = 'AutoIt'
    $meta.Item('autoit_version') = @AutoItVersion
    $extra.Item('meta') = $meta

    If $extra.Exists('env') Then
        raise(NotImplementedError, _
            "Did not expect that the third parameter of store_log_event contains a key named 'env'," _
            & " if required, you will need to implement setdefault() as known from Python.")
    EndIf
    $extra.Item('env') = ObjCreate("Scripting.Dictionary")

    ;; Currently only Implemented in AutoIt.
    ;; Move the function to Python so that all e2e-tests report env.nic_with_default_route.
    $extra.Item('env').Item('nic_with_default_route') = get_nic_name_with_default_gateway()

    Local $spool_obj = ObjCreate("Scripting.Dictionary")
    $spool_obj.Item('level') = $level
    $spool_obj.Item('msg') = $msg
    $spool_obj.Item('extra') = $extra

    Local $spool_file = get_spool_path() & '/' & get_filename_save_cur_timestamp() & '.json'

    write_as_json_file($spool_obj, $spool_file)

    Return True
EndFunc


assert_dependency_command_returns_without_errors(StringSplit("python --version", ' ', $STR_NOCOUNT))
Func run_process_log_events()
    ConsoleWrite(_getDOSOutput('..\tools\process_log_events.bat') & @CRLF)
    ConsoleWrite(_getDOSOutput('..\tools\scp_log_events.bat') & @CRLF)
EndFunc


Func get_prefixed_dict($dict, $prefix)
    Local $data = ObjCreate("Scripting.Dictionary")

    For $key In $dict
       $data.Item($prefix & "-" & $key) = $dict.Item($key)
    Next

    Return $data
 EndFunc


Func add_duration_string_in_ms_to_dict($duration_string_in_ms, $dict, $key)

   If $duration_string_in_ms == "" Then
      Return
   EndIf

   $dict.Item($key) = Round(Number($duration_string_in_ms) / 1000, 3)
EndFunc


Func get_host_fqdn()
    Local $wmic_return_string = subprocess_check_output(StringSplit("wmic computersystem get domain", ' ', $STR_NOCOUNT), True)
    Local $wmic_return_array = StringSplit(StringStripWS($wmic_return_string, BitOR($STR_STRIPLEADING, $STR_STRIPTRAILING, $STR_STRIPSPACES)), " ", $STR_NOCOUNT)
    Local $domain = $wmic_return_array[1]

    Return StringLower(@ComputerName & '.' & $domain)
EndFunc


; https://www.autoitscript.com/forum/topic/134387-version-4-uuid-generator/?tab=comments#comment-936917
;Version 4 UUID generator
;credits goes to mimec (http://php.net/uniqid#69164)
Func uuid()
    Return StringFormat('%04x%04x-%04x-%04x-%04x-%04x%04x%04x', _
            Random(0, 0xffff), Random(0, 0xffff), _
            Random(0, 0xffff), _
            BitOR(Random(0, 0x0fff), 0x4000), _
            BitOR(Random(0, 0x3fff), 0x8000), _
            Random(0, 0xffff), Random(0, 0xffff), Random(0, 0xffff) _
        )
EndFunc


;; https://www.autoitscript.com/autoit3/docs/appendix/OSLangCodes.htm
Func LCIDToLocaleName($iLCID)
    Local $aRet = DllCall("kernel32.dll", "int", "LCIDToLocaleName", "int", $iLCID, "wstr", "", "int", 85, "dword", 0)
    Return $aRet[2]
EndFunc


Func get_keyboard_layout_country_code()
    Return StringLower(StringLeft(LCIDToLocaleName("0x" & @KBLayout), 2))
EndFunc


Func get_os_lang_country_code()
    Return StringLower(StringLeft(LCIDToLocaleName("0x" & @OSLang), 2))
EndFunc

#cs
It seems that in older versions of Windows the shortcut to select the location bar in explorer.exe depended on the OS language.
It was not possible to confirm this for Windows 10/Windows Server 2016/Windows 7.
Note that the used shortcut, Alt+E is rather uncommon. Ctrl+L is the de facto standard on GNU/Linux.
Microsoft also finally started accepting this with Windows 10. Switch to Ctrl+L if Alt+E makes trouble.
#ce
Func focus_location_bar()
    if @OSVersion = "WIN_7" then
        Send("!e")
    else
        Send("^l")
    EndIf
EndFunc



Func close_all_windows()

    $var = WinList()
    For $i = 1 to $var[0][0]
        If BitAnd (WinGetState ($var[$i][1]), 2) And $var[$i][0] <> "" And $var[$i][0] <> "Program Manager" Then WinClose ($var[$i][1], "")
    Next

    sleep(1000)

    Send("{ESCAPE}")

    sleep(1000)
EndFunc


;; Ansible 'file' module: state: 'absent'
Func ensure_path_is_absent($path)
    If FileExists($path) Then
        If FileGetAttrib($path) = "D" Then
            shutil_rmtree($path)
        Else
            FileDelete($path)
        EndIf
    EndIf
EndFunc


;; Source: https://www.autoitscript.com/forum/topic/158727-script-breaking-changes-_iif/
; #FUNCTION# ====================================================================================================================
; Name...........: _Iif
; Description ...: Perform a boolean test within an expression.
; Syntax.........: _Iif($fTest, $vTrueVal, $vFalseVal)
; Parameters ....: $fTest     - Boolean test.
;                  $vTrueVal  - Value to return if $fTest is true.
;                  $vFalseVal - Value to return if $fTest is false.
; Return values .: True         - $vTrueVal
;                  False        - $vFalseVal
; Author ........: Dale (Klaatu) Thompson
; Modified.......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: Yes
; ===============================================================================================================================
Func _Iif($fTest, $vTrueVal, $vFalseVal)
    If $fTest Then
        Return $vTrueVal
    Else
        Return $vFalseVal
    EndIf
 EndFunc   ;==>_Iif


;; Based on: https://www.autoitscript.com/forum/topic/128276-display-ip-address-default-gateway-dns-servers/
Func get_nic_name_with_default_gateway()
    Local $nic_name_with_default_gateway = 'unknown'

    Local $oWMIService = ObjGet('winmgmts:{impersonationLevel = impersonate}!\\' & '.' & '\root\cimv2')
    Local $oColItems = $oWMIService.ExecQuery('Select Description, DefaultIPGateway From Win32_NetworkAdapterConfiguration Where IPEnabled = True', 'WQL', 0x30)
    If IsObj($oColItems) Then
        For $oObjectItem In $oColItems
            If Not IsString($oObjectItem.DefaultIPGateway(0)) = 0 Then
                $nic_name_with_default_gateway = $oObjectItem.Description
            EndIf
        Next
    EndIf
    Return $nic_name_with_default_gateway
EndFunc


Func get_excel_window_name_for_file_path($file_path)
    Local $window_name

    if @OSVersion = "WIN_7" then
        $window_name = get_file_name_without_extension($file_path) & ".xlsx - Excel"
    else
        $window_name = get_file_name_with_extension($file_path) & " - Excel"
    EndIf

    Return $window_name
EndFunc


Func call_func_and_log_before_and_after($func, $func_params, $log_func = _log4a_Trace)
    ;; Could pass $LOG4A_LEVEL_TRACE instead.
    ;; Currently only one paramter with $func_params is supported.
    ;; As needed, support to pass an array.

    Local $func_name = StringLower(FuncName($func))

    _log4a_Trace("Calling function " & $func_name & " with parameter: " & $func_params)
    Local $func_return_value = $func($func_params)
    _log4a_Trace("Function " & $func_name & " returned with: " & $func_return_value)

    Return $func_return_value
EndFunc


Func get_cursor_name_to_id()
    ;; AutoIt should have this in an include file as they normally do for other such constants.
    Local $cursor_name_to_id = ObjCreate("Scripting.Dictionary")
    $cursor_name_to_id.Item('UNKNOWN') = -1
    $cursor_name_to_id.Item('HAND') = 0
    $cursor_name_to_id.Item('APPSTARTING') = 1
    $cursor_name_to_id.Item('CROSS') = 3
    $cursor_name_to_id.Item('HELP') = 4
    $cursor_name_to_id.Item('IBEAM') = 5
    $cursor_name_to_id.Item('ICON') = 6
    $cursor_name_to_id.Item('NO') = 7
    $cursor_name_to_id.Item('SIZE') = 8
    $cursor_name_to_id.Item('SIZEALL') = 9
    $cursor_name_to_id.Item('SIZENESW') = 10
    $cursor_name_to_id.Item('SIZENS') = 11
    $cursor_name_to_id.Item('SIZENWSE') = 12
    $cursor_name_to_id.Item('SIZEWE') = 13
    $cursor_name_to_id.Item('UPARROW') = 14
    $cursor_name_to_id.Item('WAIT') = 15

    Return $cursor_name_to_id
EndFunc


Func get_cursor_id_to_name()
    Local $cursor_name_to_id = get_cursor_name_to_id()

    Local $cursor_id_to_name = ObjCreate("Scripting.Dictionary")
    For $cursor_name In $cursor_name_to_id
        Local $cursor_id = $cursor_name_to_id.Item($cursor_name)
        $cursor_id_to_name.Item($cursor_id) = $cursor_name
    Next

    Return $cursor_id_to_name
EndFunc


;; Example: wait_while_cursor_name('Wait')
;; This might not be a reliable way to tell when an operation is ongoing.
;; Seems Windows is more going into the multi task direction.
;; One task is not supposed to keep the whole OS busy, not even the Windows OS.
Func wait_while_cursor_name($cursor_name)
    Local $cursor_id_to_name = get_cursor_name_to_id()

    $cursor_name = StringUpper($cursor_name)

    If Not $cursor_id_to_name.Exists($cursor_name) Then
        raise(Exception, "'" & $cursor_name & "' is not a valid cursor name. Refer to the documentation of the MouseGetCursor function.")
    EndIf
    Local $cursor_id = $cursor_id_to_name.Item($cursor_name)

    While MouseGetCursor() = $cursor_id
        Sleep(50)
    WEnd
EndFunc


;; Source: https://www.autoitscript.com/forum/topic/138046-how-to-determine-if-computer-is-lockedunlocked/?tab=comments#comment-1074237
Func lockscreen_active()
    Local $lockscreen_active = False
    Local Const $hDesktop = _WinAPI_OpenDesktop('Default', $DESKTOP_SWITCHDESKTOP)
    If @error = 0 Then
        $lockscreen_active = Not _WinAPI_SwitchDesktop($hDesktop)
        _WinAPI_CloseDesktop($hDesktop)
    EndIf
    Return $lockscreen_active
 EndFunc


;===============================================================================
;
; Function Name:    _ChangeScreenRes()
; Description:      Changes the current screen geometry, colour and refresh rate.
; Version:          1.0.0.1
; Parameter(s):     $i_Width - Width of the desktop screen in pixels. (horizontal resolution)
;                   $i_Height - Height of the desktop screen in pixels. (vertical resolution)
;                   $i_BitsPP - Depth of the desktop screen in bits per pixel.
;                   $i_RefreshRate - Refresh rate of the desktop screen in hertz.
; Requirement(s):   AutoIt Beta > 3.1
; Return Value(s):  On Success - Screen is adjusted, @ERROR = 0
;                   On Failure - sets @ERROR = 1
; Forum(s):         http://www.autoitscript.com/forum/index.php?showtopic=20121
; Author(s):        Original code - psandu.ro
;                   Modifications - PartyPooper
;
;===============================================================================
Func _ChangeScreenRes($i_Width = @DesktopWidth, $i_Height = @DesktopHeight, $i_BitsPP = @DesktopDepth, $i_RefreshRate = @DesktopRefresh)
    Local Const $DM_PELSWIDTH = 0x00080000
    Local Const $DM_PELSHEIGHT = 0x00100000
    Local Const $DM_BITSPERPEL = 0x00040000
    Local Const $DM_DISPLAYFREQUENCY = 0x00400000
    Local Const $CDS_TEST = 0x00000002
    Local Const $CDS_UPDATEREGISTRY = 0x00000001
    Local Const $DISP_CHANGE_RESTART = 1
    Local Const $DISP_CHANGE_SUCCESSFUL = 0
    Local Const $HWND_BROADCAST = 0xffff
    Local Const $WM_DISPLAYCHANGE = 0x007E
    If $i_Width = "" Or $i_Width = -1 Then $i_Width = @DesktopWidth ; default to current setting
    If $i_Height = "" Or $i_Height = -1 Then $i_Height = @DesktopHeight ; default to current setting
    If $i_BitsPP = "" Or $i_BitsPP = -1 Then $i_BitsPP = @DesktopDepth ; default to current setting
    If $i_RefreshRate = "" Or $i_RefreshRate = -1 Then $i_RefreshRate = @DesktopRefresh ; default to current setting
    Local $DEVMODE = DllStructCreate("byte[32];int[10];byte[32];int[6]")
    Local $B = DllCall("user32.dll", "int", "EnumDisplaySettings", "ptr", 0, "long", 0, "ptr", DllStructGetPtr($DEVMODE))
    If @error Then
        $B = 0
        SetError(1)
        Return $B
    Else
        $B = $B[0]
    EndIf
    If $B <> 0 Then
        DllStructSetData($DEVMODE, 2, BitOR($DM_PELSWIDTH, $DM_PELSHEIGHT, $DM_BITSPERPEL, $DM_DISPLAYFREQUENCY), 5)
        DllStructSetData($DEVMODE, 4, $i_Width, 2)
        DllStructSetData($DEVMODE, 4, $i_Height, 3)
        DllStructSetData($DEVMODE, 4, $i_BitsPP, 1)
        DllStructSetData($DEVMODE, 4, $i_RefreshRate, 5)
        $B = DllCall("user32.dll", "int", "ChangeDisplaySettings", "ptr", DllStructGetPtr($DEVMODE), "int", $CDS_TEST)
        If @error Then
            $B = -1
        Else
            $B = $B[0]
        EndIf
        Select
            Case $B = $DISP_CHANGE_RESTART
                $DEVMODE = ""
                Return 2
            Case $B = $DISP_CHANGE_SUCCESSFUL
                DllCall("user32.dll", "int", "ChangeDisplaySettings", "ptr", DllStructGetPtr($DEVMODE), "int", $CDS_UPDATEREGISTRY)
                DllCall("user32.dll", "int", "SendMessage", "hwnd", $HWND_BROADCAST, "int", $WM_DISPLAYCHANGE, _
                        "int", $i_BitsPP, "int", $i_Height * 2 ^ 16 + $i_Width)
                $DEVMODE = ""
                Return 1
            Case Else
                $DEVMODE = ""
                SetError(1)
                Return $B
        EndSelect
    EndIf
EndFunc ;==>_ChangeScreenRes


Func ensure_screen_resolution_is_active($screen_width, $screen_height)
   If (not ($screen_width = @DesktopWidth)) or (not ($screen_height = @DesktopHeight)) Then
	  _ChangeScreenRes($screen_width, $screen_height)
	  If @error or (not ($screen_width = @DesktopWidth)) or (not ($screen_height = @DesktopHeight)) Then
        raise(Exception, _
            "The function ensure_screen_resolution_is_active was called to ensure that the screen resolution is set to `" _
            & $screen_width & "x" & $screen_height & "`." & _
            " This did not succeed.")
    EndIf
   EndIf
EndFunc
