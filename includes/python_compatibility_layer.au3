#cs ----------------------------------------------------------------------------

   @author Copyright (C) 2016-2018 Robin Schneider <robin.schneider@geberit.com>
   @company Copyright (C) 2016-2018 Geberit Verwaltungs GmbH https://www.geberit.de
   @license AGPL-3.0-only <https://www.gnu.org/licenses/agpl-3.0.html>

   Treat AutoIt like it is Python.
   Functions and parameters are implemented lazily (ref: "lazy loading").

#ce ----------------------------------------------------------------------------

#include-once

#include <Constants.au3>
#include <AutoItConstants.au3>
#include <Array.au3>

#include "log4a.au3"
#include "ProcessGetExitcode.au3"

#Include "common.au3"

Func print($msg)
   ConsoleWrite($msg & @CRLF)
EndFunc


;; Implements: https://docs.python.org/3/library/subprocess.html#subprocess.call
Func subprocess_call($args, $show_flag=Default, $shell=False)
    Local $pid, $handle_pid, $process_output = '', $exit_code

    ;; Run the process with stdout flag STDERR_MERGED.
    If $shell Then
        ;; WARNING: This is not safe against shell injection. This is to be expected but still, take care when you use it.
        ;; You might need to use it because $shell=False is not as powerful as it should be.
        ;; For example `check_dependency_command` needs to use $shell=True even when a shell is technical not required for this.
        $pid = Run('"' & @ComSpec & '" /c ' & _ArrayToString($args, " "), '', $show_flag, $STDERR_MERGED)
    Else
        $pid = Run(_ArrayToString($args, " "), '', $show_flag, $STDERR_MERGED)
    EndIf
    $handle_pid = _ProcessOpenHandle($pid)

    Do
        Sleep(1)
        $process_output &= StdOutRead($pid)
    Until @error

    ; Require process to be closed before calling _ProcessGetExitCode().
    ProcessWaitClose($pid)

    $exit_code = _ProcessGetExitCode($handle_pid)
    _ProcessCloseHandle($handle_pid)

    If Not $process_output == '' Then
        _log4a_Trace('Command output: ' & $process_output)
    EndIf
    Return $exit_code
EndFunc


;; Implements: https://docs.python.org/3/library/subprocess.html#subprocess.check_output
Func subprocess_check_output($args, $stderr=False)

    Local $pid, $handle_pid, $process_output = '', $exit_code

    local $run_flags = 0
    If $stderr Then
        $run_flags = BitOR($run_flags, $STDERR_MERGED)
    EndIf

    ;; Run the process with stdout flag STDERR_MERGED.
    ;; WARNING: This is not safe against shell injection.
    ;; The interface to subprocess_call is designed so that this can be fixed in the function only later
    ;; when it is known how this can be done with AutoIt and M$ Windows.
    $pid = Run('"' & @ComSpec & '" /c ' & _ArrayToString($args, " "), '', Default, $run_flags)
    $handle_pid = _ProcessOpenHandle($pid)

    Do
        Sleep(1)
        $process_output &= StdOutRead($pid)
    Until @error

    ; Require process to be closed before calling _ProcessGetExitCode().
    ProcessWaitClose($pid)

    $exit_code = _ProcessGetExitCode($handle_pid)
    _ProcessCloseHandle($handle_pid)

    If Not $exit_code = 0 Then
        raise(OSError, _ArrayToString($args, " ") & " exited with " & $exit_code)
    EndIf

    Return $process_output
EndFunc


;; https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard
;; Note that the Filesystem Hierarchy Standard (FHS) is not common on Windows, we use it anyway because Windows has nothing appropriate.
Func get_temporary_directory($suffix='', $prefix='', $dir='')
    If $dir = '' Then
        ;; Too busy/actively used by other applications.
        ; $dir = @TempDir

        ; $dir = 'c:/temp'

        ;; Windows has become permissive enough to accept forward slashes as directory separator.
        ;; Seems some AutoIt functions don’t fully work with normal slashes yet.
        ;; Use this function for such cases so that we can still use unified file paths which work on all modern platforms everywhere.
        $dir = 'c:/tmp'
    EndIf

    ; _WinAPI_GetTempFileName could be used here but it seems not as flexible as we are used to from Python.
    Local $tmp_path = $dir & '/' & $suffix & uuid() & $prefix

    If FileExists($tmp_path) Then
        raise(Exception, "Random temporary directory already exists: " & $tmp_path)
    EndIf

    os_makedirs($tmp_path)

    Return $tmp_path
EndFunc


; AutoIt does not have exceptions but we still need to handle errors in some proper way so we reimplement the exceptions from Python as needed.
; Inventing new exceptions is ok when no matching one exists. This is common in the Python world.
; https://docs.python.org/3/library/exceptions.html
Func raise($exception, $strerror)
    $exception($exception, $strerror)
EndFunc


Func Exception($self, $strerror)
    Local $exception_all_uppercase_to_camel_case = ObjCreate("Scripting.Dictionary")
    $exception_all_uppercase_to_camel_case.Item('EXCEPTION') = 'Exception'
    $exception_all_uppercase_to_camel_case.Item('TYPEERROR') = 'TypeError'
    $exception_all_uppercase_to_camel_case.Item('OSERROR') = 'OSError'
    $exception_all_uppercase_to_camel_case.Item('DEPENDENCYNOTFOUNDERROR') = 'DependencyNotFoundError'
    $exception_all_uppercase_to_camel_case.Item('RUNTIMEERROR') = 'RuntimeError'
    $exception_all_uppercase_to_camel_case.Item('NOTIMPLEMENTEDERROR') = 'NotImplementedError'

    Local $exception_name = FuncName($self)
    If $exception_all_uppercase_to_camel_case.Exists($exception_name) Then
        $exception_name = $exception_all_uppercase_to_camel_case.Item($exception_name)
    EndIf

    _log4a_Fatal($exception_name & ': ' & $strerror)
    MsgBox($MB_ICONERROR, "e2e-tests: " & $exception_name, $strerror)
    Exit(1)
EndFunc


Func TypeError($self, $strerror)
    Exception($self, $strerror)
EndFunc


Func OSError($self, $strerror)
    Exception($self, $strerror)
EndFunc


Func FileNotFoundError($self, $strerror)
    OSError($self, $strerror)
EndFunc


Func DependencyNotFoundError($self, $strerror)
    Exception($self, $strerror)
EndFunc


Func RuntimeError($self, $strerror)
    Exception($self, $strerror)
EndFunc


Func NotImplementedError($self, $strerror)
    RuntimeError($self, $strerror)
EndFunc


;; https://docs.python.org/3/library/os.html#os.makedirs
Func os_makedirs($name)
    If Not DirCreate(get_windows_path($name)) Then
        raise(OSError, "Could not create directory: " & $name)
    EndIf
EndFunc


;; https://docs.python.org/3/library/os.html#os.unlink
Func os_unlink($path)
    If Not FileDelete($path) Then
        raise(OSError, "Could not delete file path: " & $path)
    EndIf
EndFunc


;; https://docs.python.org/3/library/shutil.html#shutil.rmtree
Func shutil_rmtree($path)
    If Not DirRemove($path, $DIR_REMOVE) Then
        raise(OSError, "Could not delete directory path: " & $path)
    EndIf
EndFunc
