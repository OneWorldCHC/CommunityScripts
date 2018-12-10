<#
.Synopsis
    WinPE WIM File XenServer Tools Injector
.DESCRIPTION
    This script will automatically inject XenServer Tools into a WinPE WIM file so that the XS Paravirtual Driver can be used for gigabit eithernet. Not using this method
    will result in the Realtek driver remaining in the image and the VM will detect and use that instead. The script will loop through all MDT Deployment Shares defined in the variables section. 
    It will then create a bootable ISO file for each deployment share.

    Pre-requisites: Windows Assessment and Deployment Kit, Microsoft Deployment Tools, A downloaded copy of XenServer tools MSI. 
    Assumptions: That MDT has created your WIM files already. That you want an ISO file as the final media.
.EXAMPLE
    Inject XS Tools Into WIM.ps1
.NOTES
    Created:	 2018-12-07
    Updated:     2018-12-07
    Version:	 1.0
        
    Author(s) : 
                Steve Elgan
    Disclaimer:
    This script is provided 'AS IS' with no warranties, confers no rights and 
    is not supported by the author.
.LINK
    https://stackoverflow.com/questions/20790798/start-process-wait-doesnt-work-when-script-is-launched-from-command-prompt-ope
    https://www.xenappblog.com/blog
    https://forums.veeam.com/veeam-agent-for-windows-f33/veeam-bare-metal-recovery-on-xenserver-with-pv-nic-drivers-t48304.html
#>


#Declare variables
#Change these to your liking.
$MDTShares = "D:\MDTBuildLab","D:\MDTProduction" #each deployment share path should be defined.
$DestISO = "MDT_XSLab_x64.iso","MDT_XSProduction_x64.iso" #The quanity of values in this array should match $MDTShares.
$XSTools = $MDTShares[1] + "\Applications\Citrix\XenServer\7.1.0.1305\managementagentx64.msi" #Where you store your XS Tools
$TempDir = "D:\Temp" 

#Don't change these unless you are customizing the script behavior.
$ExtractDir = "$TempDir\XSTools"
$MountDir = "$TempDir\Mount"
$WIMFileName = "LiteTouchPE_x64.wim"
$WAIKitDir = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
$env:WinPERoot = $WAIKitDir
$OSCDIMGDir = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\AMD64\Oscdimg"
$env:OSCDImgRoot = $OSCDIMGDir
$DriverPaths = "$MountDir\Windows\system32\DriverStore\FileRepository\netrtl64.inf_amd64_8e9c2368fe308df2","$MountDir\Windows\WinSxS\amd64_netrtl64.inf_31bf3856ad364e35_10.0.16299.15_none_cc07f879fba34860","$MountDir\Windows\WinSxS\amd64_netrtl64.inf.resources_31bf3856ad364e35_10.0.16299.15_en-us_45ec42bc03abec68"
$User = $env:USERDOMAIN +"\" + $env:USERNAME
$PEDir = "$TempDir\WinPE"

$StartDTM = (Get-Date)

#Extract the tools.
If (Test-Path $TempDir) {
    Write-Verbose "Temp Dir Exists" -Verbose
}
Else {
    Write-Verbose "Creating Temp Dir" -Verbose
    New-Item -Path $TempDir -ItemType Directory -Verbose
}

Write-Verbose "Copy XenServer Tools from $XSTools to $TempDir" -Verbose
Copy-Item -Path $XSTools -Destination $TempDir -Force -Verbose

Write-Verbose "Extracting XenServer Tools" -Verbose
Start-Process msiexec.exe -ArgumentList "/a $XSTools /qb TARGETDIR=$ExtractDir" -WindowStyle Hidden -Wait -Verbose

#Loop through deployment shares.

$i = 0
ForEach ($Share in $MDTShares) {
    #Mount the WIM.
    If (Test-Path $MountDir) {
        Write-Verbose "Mount Dir Exists" -Verbose
    }
    Else {
        Write-Verbose "Creating Mount Dir" -Verbose
        New-Item -Path $MountDir -ItemType Directory -Verbose
    }

    If (Test-Path "$TempDir\$WIMFileName") {
        Write-Verbose "WIM File Exists, removing it" -Verbose
        Remove-Item "$TempDir\$WIMFileName" -Verbose -Force
    }

    Copy-Item -Path "$Share\boot\$WIMFileName" -Destination $TempDir -Force -Verbose

    #Dism hangs so this method addresses that. 
    Write-Verbose "Mounting WIM File" -Verbose

    $proc = Start-Process dism.exe -ArgumentList "/mount-wim /wimfile:$TempDir\$WIMFileName /index:1 /mountdir:$MountDir" -WindowStyle Hidden -Passthru -Verbose
    do {start-sleep -Milliseconds 500}
    until ($proc.HasExited)

    Foreach ($Path in $DriverPaths) {
        If (Test-Path -Path $Path) {
            Write-Verbose "Taking ownership of $Path" -Verbose

            Start-Process Takeown.exe -ArgumentList "/F $Path /R /D Y" -Wait -Verbose -WindowStyle Hidden 
        
            $acl = Get-Acl -Path $Path
        
            $permission = "$User","FullControl","ContainerInherit,ObjectInherit","None","Allow"
        
            $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $permission
        
            $acl.SetAccessRule($accessRule)
        
            $acl | Set-Acl -Path $Path
        
            Get-ChildItem -Path $Path -Recurse | ForEach-Object{
                $acl | Set-Acl -Path $_.FullName -Verbose
            }
            Remove-Item -Path $Path -Recurse -Force -Verbose
        }
        Else {
            Write-Verbose "$Path folder not present" -Verbose
        }

    }

    #Inject XS Tools Drivers into the WIM.
    Write-Verbose "Injecting XenServer Tools into Mounted WIM" -Verbose

    Start-Process dism.exe -ArgumentList "/Image:$MountDir /Add-Driver /Driver:$ExtractDir\Citrix\XenTools /Recurse" -WindowStyle Hidden -Wait -Verbose

    #Unmount the WIM
    Write-Verbose "Dismounting WIM File" -Verbose
    Start-Process Dism.exe -ArgumentList "/Unmount-Image /MountDir:$MountDir /Commit" -WindowStyle Hidden -Wait -Verbose

    #Start-Process Dism.exe -ArgumentList "/Unmount-Image /MountDir:$MountDir /Discard" -Wait 

    #Create ISO From WIM
    Write-Verbose "Removing WinPE Directory if Exists" -Verbose
    If (Test-Path $PEDir) {
        Write-Verbose "WinPE Dir Exists" -Verbose
        Remove-Item $PEDir -Force -Recurse -Verbose
    }

    Write-Verbose "Chaning Directory to $WAIKitDir" -Verbose
    Set-Location -Path "$WAIKitDir"

    Write-Verbose "Staging WinPE Files" -Verbose
    Start-Process cmd.exe -ArgumentList "/c copype.cmd amd64 $PEDir" -WindowStyle Hidden -Wait -Verbose

    Write-Verbose "Copying Modified WIM file to PE Directory" -Verbose
    Copy-Item -Path "$TempDir\$WIMFileName" -Destination "$PEDIR\media\sources\boot.wim" -Force -Verbose

    Write-Verbose "Copying oscdimg.exe to $WAIKitDir" -Verbose
    Copy-Item -Path "$OSCDIMGDir\oscdimg.exe" .\ -Verbose

    Write-Verbose "Creating ISO file at $Tempdir\$($DestISO[$i])" -Verbose
    Start-Process cmd.exe -ArgumentList "/c MakeWinPEMedia.cmd /ISO /f $PEDir $Tempdir\.\$($DestISO[$i])" -WindowStyle Hidden -Wait -Verbose
    $i++

}
$EndDTM = (Get-Date)
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalSeconds) Seconds" -Verbose
Write-Verbose "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
