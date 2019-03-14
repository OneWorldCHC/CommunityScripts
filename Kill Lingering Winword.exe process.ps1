<#
.SYNOPSIS
  Name: script.ps1
  The purpose of this script is to look for lingering winword.exe processes that were launched with the command line winword.exe /Automation -Embedding. Upon finding such a process, if it's existed for 5 minutes or more, kill it. 
  
.DESCRIPTION
  This is to compensate for a bug in NextGen that leaves the process lingering on the Citrix servers. Normal winword.exe launches do not have the /Automation -Embedding switches so that's why we key off those. It is designed to run
  as a scheduled task. 

.NOTES
    Release Date: 2019-03-14
   
  Author: David Ott (Citrix CTA) @david62277
  Contributor: Steve Elgan (Citrix CTA) @selgan - added event log logic

#>


$process = gwmi -Class win32_process -Filter {name = 'winword.exe' and commandline like '%automation -embedding'} | select handle,@{n='starttime';e={[System.Management.ManagementDateTimeconverter]::ToDateTime($_.CreationDate)}} | ?{$_.starttime -le (get-date).AddMinutes(-5)}

gwmi -Class win32_process -Filter {name = 'winword.exe' and commandline like '%automation -embedding'} | select handle,@{n='starttime';e={[System.Management.ManagementDateTimeconverter]::ToDateTime($_.CreationDate)}} | ?{$_.starttime -le (get-date).AddMinutes(-5)} | %{stop-process $_.handle -force}

ForEach ($handle in $process){
    Write-EventLog -LogName Application -Source "EventCreate" -EventID 0001 -EntryType Information -Message "A OneWorld PowerShell Scheduled Task killed process $($handle.handle) because it was hogging CPU for 5 minutes or more." 
}

