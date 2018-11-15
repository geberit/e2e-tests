;; +    Shift
;; ^    Control
;; #    Super (Windows logo key)
;; !    Alt

#SingleInstance force
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

SetTitleMatchMode, RegEx

;; Refer to ../includes/sikulix_common.sikuli/sikulix_common.py, `start_time_measurement`


;; Signal start of measurement.
+#I::
    ; Suspend, Permit
    ; Suspend, off
    menu, tray, icon, famfamfam_silk_icons/eye.ico
Return

;; Signal stop of measurement.
+#O::
    ; Suspend, Permit
    ; Suspend, on
    menu, tray, icon, famfamfam_silk_icons/stop.ico
Return
