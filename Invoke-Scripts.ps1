#Requires -RunAsAdministrator
#Requires -PSEdition Desktop
<#
    .SYNOPSIS
    Configuration changes to a default install of Windows during provisioning.
  
    .NOTES
    NAME: Invoke-Scripts.ps1
    AUTHOR: Aaron Parker
    TWITTER: @stealthpuppy
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = $(Split-Path -Path $script:MyInvocation.MyCommand.Path -Parent),

    [Parameter(Mandatory = $False)]
    [System.String] $Guid = "f38de27b-799e-4c30-8a01-bfdedc622944",

    [Parameter(Mandatory = $False)]
    [System.String] $Publisher = "stealthpuppy",

    [Parameter(Mandatory = $False)]
    [System.String] $DisplayName = "Install detection for image customisations",
    
    [Parameter(Mandatory = $False)]
    [System.String] $RunOn = $(Get-Date -Format "yyyy-MM-dd"),
    
    [Parameter(Mandatory = $False)]
    [System.String] $Version = (Get-ChildItem -Path $PWD -Filter "VERSION.txt" -Recurse | Get-Content -Raw)
)

Write-Verbose -Message "Execution path: $Path."
Write-Verbose -Message "Customisation scripts version: $Version."

# Get system properties
Switch -Regex ((Get-WmiObject -Class "Win32_OperatingSystem").Caption) {
    "Microsoft Windows Server*" {
        $Platform = "Server"
    }
    "Microsoft Windows 10 Enterprise for Virtual Desktops" {
        $Platform = "Multi"
    }
    "Microsoft Windows 10*" {
        $Platform = "Client"
    }
}
$Build = ([System.Environment]::OSVersion.Version).Build
If ((Get-WmiObject -Computer . -Class "Win32_ComputerSystem").Model -match "Parallels*|VMware*|Virtual*") {
    $Model = "Virtual"
}
Else {
    $Model = "Physical"
}

# Gather scripts
try { $AllScripts = @(Get-ChildItem -Path $PWD -Filter "*.All.ps1" -Recurse -ErrorAction "SilentlyContinue") } catch { Throw $_.Exception.Message }
try { $PlatformScripts = @(Get-ChildItem -Path $PWD -Filter "*.$Platform.ps1" -Recurse -ErrorAction "SilentlyContinue") } catch { Throw $_.Exception.Message }
try { $BuildScripts = @(Get-ChildItem -Path $PWD -Filter "*.$Build.ps1" -Recurse -ErrorAction "SilentlyContinue") } catch { Throw $_.Exception.Message }
try { $ModelScripts = @(Get-ChildItem -Path $PWD -Filter "*.$Model.ps1" -Recurse -ErrorAction "SilentlyContinue") } catch { Throw $_.Exception.Message }

# Run all scripts
ForEach ($script in ($AllScripts + $PlatformScripts + $BuildScripts + $ModelScripts)) {
    try {
        Write-Verbose -Message "Running script: $($script.FullName)."
        & $script.FullName
    }
    catch {
        Write-Warning -Message "Failed to run script: $($script.FullName)."
        Throw $_.Exception.Message
    }
}

# Set uninstall registry value for detecting in MDT / ConfigMgr etc.
$Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
reg add "$Key\{$Guid}" /v "DisplayName" /d $DisplayName /t REG_SZ /f
reg add "$Key\{$Guid}" /v "Publisher" /d $Publisher /t REG_SZ /f
reg add "$Key\{$Guid}" /v "DisplayVersion" /d $Version /t REG_SZ /f
reg add "$Key\{$Guid}" /v "RunOn" /d $RunOn /t REG_SZ /f
