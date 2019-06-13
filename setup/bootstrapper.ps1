## It is called M$ Shell!
$host.ui.RawUI.WindowTitle = "M$ Shell"

function Assert-ChocoLastExitCodeIsOK {
    # As of chocolatey 0.9.10, non-zero success exit codes can be returned
    # See https://github.com/chocolatey/choco/issues/512#issuecomment-214284461
    $successexitcodes = (0, 1605, 1614, 1641, 3010)

    if ($LastExitCode -notin $SuccessExitCodes) {
        throw "Choco command did not exit successfully. Exiting the script."
    }
}

function Assert-LastExitCodeIsZero {
    if ($LastExitCode -ne 0) {
        throw "Last command did not exit successfully. Exiting the script."
    }
}

function Get-Boxstarter {
    Param(
        [string] $Version = "2.10.3",
        [switch] $Force
    )
    if(!(Test-Admin)) {
        $bootstrapperFile = ${function:Get-Boxstarter}.File
        if($bootstrapperFile) {
            Write-Host "User is not running with administrative rights. Attempting to elevate..."
            $command = "-ExecutionPolicy bypass -noexit -command . '$bootstrapperFile';Get-Boxstarter $($args)"
            Start-Process powershell -verb runas -argumentlist $command
        }
        else {
            Write-Host "User is not running with administrative rights.`nPlease open a powershell console as administrator and try again."
        }
        return
    }

    $badPolicy = $false
    @("Restricted", "AllSigned") | ? { $_ -eq (Get-ExecutionPolicy).ToString() } | % {
        Write-Host "Your current Powershell Execution Policy is set to '$(Get-ExecutionPolicy)' and will prohibit boxstarter from operating propperly."
        Write-Host "Please use Set-ExecutionPolicy to change the policy to RemoteSigned or Unrestricted."
        $badPolicy = $true
    }
    if($badPolicy) { return }

    Write-Output "Welcome to the Boxstarter Module installer!"
    if(Check-Chocolatey -Force:$Force){
        Write-Output "Chocolatey installed, Installing Boxstarter Modules."
        $chocoVersion  = "2.9.17"
        try {
            New-Object -TypeName Version -ArgumentList $chocoVersion.split('-')[0] | Out-Null
            $command = "cinst Boxstarter -y"
        }
        catch{
            # if there is no -v then its an older version with no -y
            $command = "cinst Boxstarter"
        }
        $command += " --version $version"
        Invoke-Expression $command
        Import-Module "$env:ProgramData\boxstarter\boxstarter.chocolatey\boxstarter.chocolatey.psd1" -Force
        $Message = "Boxstarter Module Installer completed"
    }
    else {
        $Message = "Did not detect Chocolatey and unable to install. Installation of Boxstarter has been aborted."
    }
    if($Force) {
        Write-Host $Message
    }
    else {
        Write-Host $Message
        # Read-Host $Message
    }
    cd $PSScriptRoot
    $ErrorActionPreference = "Stop"

    ## /SChannel is considered unstable.
    cinst -y git.install --params "/GitAndUnixToolsOnPath"
    Assert-ChocoLastExitCodeIsOK

    ## On Windows 7 and Windows 10, the install script for git seems not to be able to setup the PATH correctly.
    ## Note that this task is a configuration management task. This script will add the value multiple times. We don’t care.
    ## Edit: Only reinstall for git helped. This is a confirmed issue. Uninstall git with choco and run the script again when that happens.
    ## Automated uninstall and install does not work.
    # cuninst -y git.install
    # cinst -y git.install --params "/GitAndUnixToolsOnPath"
    # setx PATH "$env:path;C:/Program Files/Git/cmd;C:/Program Files/Git/mingw64/bin;C:/Program Files/Git/usr/bin" -m

    ## Hard dependencies:
    cinst -y git vim autoit python python2 python3 conemu clink openssl.light autologon puppet-agent
    Assert-ChocoLastExitCodeIsOK

    ## Ref: https://stackoverflow.com/questions/46758437/how-to-refresh-the-environment-of-a-powershell-session-after-a-chocolatey-instal/46760714#46760714
    $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).path)/../.."
    Import-Module "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1"
    refreshenv

    ## puppet-agent is only installed to get facter.

    ## Not supported for python2 package. This is not an issue, Python2 is not going to be updated soon anyway.
    ## cinst -y python2 --params "/InstallDir:c:/Python2/"
    ## Noticed the same issue with python3 package as well. Considering this InstallDir parameter as unreliable.
    # cinst -y python2
    # cinst -y python3 --params "/InstallDir:c:/Python3/"

    ## On Windows 10, the install script for python seems not to be able to setup the PATH correctly anymore.
    ## Later it worked on a new Windows 10 VM again so we drop the workaround again.
    # setx PATH "$env:path;C:/Python27" -m

    ## On Windows 7, the install script for OpenSSL seems not to be able to setup the PATH correctly.
    # setx PATH "$env:path;C:/Program Files/OpenSSL/bin" -m

    ## Note: SikuliX is provided as part of the e2e-tests code base currently because the choco package of it is not up-to-date.
    ## Also, we might need more current/nightly versions of SikuliX.

    ## Soft dependencies. Provides additional functionally like Logstash output and `env.uptime`.
    c:/python27/scripts/pip2.exe install python-logstash-async simplejson pathlib2 uptime psutil backports.functools_lru_cache
    Assert-LastExitCodeIsZero

    ## Soft dependencies. Nice to have for development and debugging:
    cinst -y ag obs-studio smplayer sqlitebrowser autohotkey imageglass kitty treesizefree regjump sudo openssh
    Assert-ChocoLastExitCodeIsOK

    ## Don't install Wireshark by default: wireshark winpcap

    c:/python37/scripts/pip3.exe install wmi
    Assert-LastExitCodeIsZero

    # & "C:/Program Files/Git/git-bash.exe" -c "./setup_ssh_known_hosts.sh"

    ## Update this clone statement with the appropriate repo.
    git clone --recursive 'https://github.com/geberit/e2e-tests.git' c:/e2e-tests

    git -C 'c:/e2e-tests' checkout master
    Assert-LastExitCodeIsZero

    mkdir -f "c:/var/lib/e2e-tests" > $null

    $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
    New-Item -Path $RegPath -ErrorAction SilentlyContinue
    New-ItemProperty -Path $RegPath -Type "DWORD" -Name "NoLockScreen" -Value 1 -ErrorAction SilentlyContinue
}

function Check-Chocolatey {
    Param(
        [switch] $Force
    )
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall\bin\choco.exe")){
        $message = "Chocolatey is going to be downloaded and installed on your machine. If you do not have the .NET Framework Version 4 or greater, that will also be downloaded and installed."
        Write-Host $message
        if($Force -OR (Confirm-Install)){
            $exitCode = Enable-Net40
            if($exitCode -ne 0) {
                Write-Warning ".net install returned $exitCode. You likely need to reboot your computer before proceeding with the install."
                return $false
            }
            $env:ChocolateyInstall = "$env:programdata\chocolatey"
            New-Item $env:ChocolateyInstall -Force -type directory | Out-Null
            $url="https://chocolatey.org/api/v2/package/chocolatey/"
            $wc=new-object net.webclient
            $wp=[system.net.WebProxy]::GetDefaultProxy()
            $wp.UseDefaultCredentials=$true
            $wc.Proxy=$wp
            iex ($wc.DownloadString("https://chocolatey.org/install.ps1"))
            $env:path="$env:path;$env:ChocolateyInstall\bin"
        }
        else{
            return $false
        }
    }
    return $true
}

function Is64Bit {  [IntPtr]::Size -eq 8  }

function Enable-Net40 {
    if(Is64Bit) {$fx="framework64"} else {$fx="framework"}
    if(!(test-path "$env:windir\Microsoft.Net\$fx\v4.0.30319")) {
        Write-Host "Downloading .net 4.5..."
        Get-HttpToFile "http://download.microsoft.com/download/b/a/4/ba4a7e71-2906-4b2d-a0e1-80cf16844f5f/dotnetfx45_full_x86_x64.exe" "$env:temp\net45.exe"
        Write-Host "Installing .net 4.5..."
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "$env:temp\net45.exe"
        $pinfo.Verb="runas"
        $pinfo.Arguments = "/quiet /norestart /log $env:temp\net45.log"
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        $p.WaitForExit()
        $e = $p.ExitCode
        if($e -ne 0){
            Write-Host "Installer exited with $e"
        }
        return $e
    }
    return 0
}

function Get-HttpToFile ($url, $file){
    Write-Verbose "Downloading $url to $file"
    if(Test-Path $file){Remove-Item $file -Force}
    $downloader=new-object net.webclient
    $wp=[system.net.WebProxy]::GetDefaultProxy()
    $wp.UseDefaultCredentials=$true
    $downloader.Proxy=$wp
    try {
        $downloader.DownloadFile($url, $file)
    }
    catch{
        if($VerbosePreference -eq "Continue"){
            Write-Error $($_.Exception | fl * -Force | Out-String)
        }
        throw $_
    }
}

function Confirm-Install {
    $caption = "Installing Chocolatey"
    $message = "Do you want to proceed?"
    $yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Yes";
    $no = new-Object System.Management.Automation.Host.ChoiceDescription "&No","No";
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no);
    $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)

    switch ($answer){
        0 {return $true; break}
        1 {return $false; break}
    }
}

function Test-Admin {
    $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal( $identity )
    return $principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator )
}
