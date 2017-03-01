function Test-PendingReboot {
  Write-Progress -Activity "Testing if a reboot is needed"
  Write-Verbose "Testing if reboot is needed"
  if ((Get-PendingReboot).RebootPending) { Read-Host "Reboot needed. Please restart the computer and then rerun this script."; break }
}
