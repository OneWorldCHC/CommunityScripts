# Description

This script is intended to be used with Microsoft Deployment Tools (MDT) when also using XenServer as the hypervisor. This script will mount one or more WIM files and inject XenServer Tools into the WIM. It will remove the Realtek driver and then add some registry keys into the WIM. It will then create a new ISO file for each MDT deployment share. All of this is to enable gigabit speed in Windows PE for XenSever guest VMs.

## Getting Started

Open the powershell script. Edit the variables appropriately and then execute. 

```
#Change these to your liking.
$MDTShares = "D:\MDTBuildLab","D:\MDTProduction" #each deployment share path should be defined.
$DestISO = "MDT_XSLab_x64.iso","MDT_XSProduction_x64.iso" #The quanity of values in this array should match $MDTShares.
$XSTools = $MDTShares[1] + "\Applications\Citrix\XenServer\7.1.0.1305\managementagentx64.msi" #Where you store your XS Tools
$TempDir = "D:\Temp" 
```

## Known Issues

Using the customized ISO file on a different hypervisor may cause the Windows PE to blue screen. For these scenarios, use the ISO generated by MDT directly. 
