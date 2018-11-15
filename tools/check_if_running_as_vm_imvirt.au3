#cs ----------------------------------------------------------------------------

    @author Copyright (C) 2018 Robin Schneider <robin.schneider@geberit.com>
    @company Copyright (C) 2018 Geberit Verwaltungs GmbH https://www.geberit.de
    @license AGPL-3.0-only <https://www.gnu.org/licenses/agpl-3.0.html>

    Implementation for other languages: ./check_if_running_as_vm_imvirt.py

    TODO: Known issues: It happened once that this code returned "Not a VM" inside a VM.
    Happened for 1 run out of ~3000 runs. This is currently not reproducible
    and the circumstance is unclear.

#ce ----------------------------------------------------------------------------

Opt("MustDeclareVars", 1)

#include "../includes/common.au3"

Local $running_in_vm = False

Local $oWMIService = ObjGet('winmgmts:{impersonationLevel = impersonate}!\\' & '.' & '\root\cimv2')
Local $oColItems = $oWMIService.ExecQuery('select Manufacturer,Model from win32_computersystem', 'WQL', 0x30)
If IsObj($oColItems) Then
    For $oObjectItem In $oColItems

        ;; Check for VMware VM:
        If StringInStr($oObjectItem.Manufacturer, "vmware") Then
            print("Detected VMware hypervisor.")
            $running_in_vm = True
            ExitLoop
        EndIf

    Next
EndIf

If $running_in_vm Then
    print("Running as guest on a Hypervisor. We took the blue pill and are inside the matrix.")
Else
    print("Running on bare metal. Welcome to the real world, we took the red pill and escaped the matrix.")
EndIf

Exit not $running_in_vm
