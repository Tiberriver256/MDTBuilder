#Requires -Modules xWindowsUpdate

function Invoke-WSUSSetupAndConfig {


  configuration DeployWSUS
  {

    param(
      [Parameter(Mandatory = $true)]
      [string[]]$Servers
    )

    Import-DscResource -ModuleName xWindowsUpdate

    node $Servers
    {

      windowsfeature UpdateServices-Services
      {
        Name = "UpdateServices-Services"
        Ensure = "Present"
      }

      windowsfeature UpdateServices-WidDB
      {
        Name = "UpdateServices-WidDB"
        Ensure = "Present"
      }

      windowsfeature UpdateServices-RSAT
      {
        Name = "UpdateServices-RSAT"
        Ensure = "Present"
        IncludeAllSubFeature = $true
      }

      file WSUS
      {
        Type = "Directory"
        Ensure = "Present"
        DestinationPath = 'D:\WSUS'
      }

      script PostWSUSConfig
      {
        SetScript = {
          Set-Location "C:\Program Files\Update Services\Tools\"
          .\wsusutil.exe postinstall CONTENT_DIR=D:\WSUS
        }

        TestScript = {
          $CDIR0 = 'D:\WSUS'
          $WSUSKey = "hklm:\SOFTWARE\Microsoft\Update Services\Server\Setup"
          $WSUSValues = Get-ItemProperty $WSUSKey
          $CDIR1 = $WSUSValues.ContentDir
          $CDIR1 -eq $CDIR0
        }

        GetScript = {
          $WSUSKey = "hklm:\SOFTWARE\Microsoft\Update Services\Server\Setup"
          $WSUSValues = Get-ItemProperty $WSUSKey
          $WSUSValues.ContentDir
        }

      }

      xhotfix WSUSWin10Support
      {
        Ensure = "Present"
        Path = "https://download.microsoft.com/download/D/3/8/D3854613-B1DB-40A2-BB05-5FF9CCDEFB74/Windows8.1-KB3095113-v2-x64.msu"
        Id = "KB3095113"
      }

    }
  }


  #Commands to execute:
  DeployWSUS -Servers localhost -OutputPath $WorkingDirectory

  Start-DscConfiguration -Path $WorkingDirectory -Wait -Verbose -Force -ErrorAction Stop

  Write-Verbose "Get WSUS Server Object" -Verbose

  $wsus = Get-WSUSServer

  Write-Verbose "Connect to WSUS server configuration" -Verbose

  $wsusConfig = $wsus.GetConfiguration()

  Write-Verbose "Set to download updates from Microsoft Updates" -Verbose

  Set-WsusServerSynchronization -SyncFromMU

  Write-Verbose "Set Update Languages to English and save configuration settings" -Verbose

  $wsusConfig.AllUpdateLanguagesEnabled = $false
  $wsusConfig.SetEnabledUpdateLanguages("en")
  $wsusConfig.Save()

  Write-Verbose "Get WSUS Subscription and perform initial synchronization to get latest categories" -Verbose

  $subscription = $wsus.GetSubscription()
  $subscription.StartSynchronizationForCategoryOnly()

  while ($subscription.GetSynchronizationStatus() -ne 'NotProcessing') {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
  }

  Write-Verbose "Sync is done" -Verbose

  Write-Verbose "Disable Products" -Verbose

  Get-WSUSServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Office" } | Set-WsusProduct -Disable
  Get-WSUSServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows" } | Set-WsusProduct -Disable

  Write-Verbose "Enable Products" -Verbose

  Get-WSUSServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows 10" } | Set-WsusProduct

  Write-Verbose "Configure the Classifications" -Verbose

  Get-WsusClassification | Where-Object {
    $_.Classification.title -in (
      'Critical Updates',
      'Definition Updates',
      'Feature Packs',
      'Security Updates',
      'Service Packs',
      'Update Rollups',
      'Updates',
      'Upgrades')
  } | Set-WsusClassification

  Write-Verbose "Configure Synchronizations" -Verbose

  $subscription.SynchronizeAutomatically = $true

  Write-Verbose "Set synchronization scheduled for midnight each night" -Verbose

  $subscription.SynchronizeAutomaticallyTimeOfDay = (New-TimeSpan -Hours 5)
  $subscription.NumberOfSynchronizationsPerDay = 1
  $subscription.Save()

  Write-Verbose "Kick Off Synchronization" -Verbose

  $subscription.StartSynchronization()

  Write-Verbose "Monitor Progress of Synchronisation" -Verbose

  Start-Sleep -Seconds 60 # Wait for sync to start before monitoring
  while ($subscription.GetSynchronizationProgress().ProcessedItems -ne $subscription.GetSynchronizationProgress().TotalItems) {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
  }



  #Change server name and port number and $True if it is on SSL

  $Computer = $env:COMPUTERNAME
  [string]$updateServer1 = $Computer
  [boolean]$useSecureConnection = $False
  [int32]$portNumber = 8530

  Write-Verbose "Load .NET assembly" -Verbose

  [void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
  $count = 0

  Write-Verbose "Connect to WSUS Server" -Verbose

  $updateServer = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($updateServer1,$useSecureConnection,$portNumber)

  Write-Verbose "Connected successfully" -Verbose

  $updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
  $u = $updateServer.GetUpdates($updatescope)

  foreach ($u1 in $u) {
    if ($u1.IsSuperseded -eq 'True') {
      $u1.Decline()
      $count = $count + 1
    }
  }

  Write-Verbose "Total Declined Updates : $count" -Verbose

  trap {
    Write-Host "Error Occurred"
    Write-Host "Exception Message: "
    Write-Host $_.Exception.Message
    Write-Host $_.Exception.StackTrace
    exit
  }

  Write-Verbose "Configure Default Approval Rule" -Verbose

  [void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
  $rule = $wsus.GetInstallApprovalRules() | where {
    $_.Name -eq "Default Automatic Approval Rule" }
  $class = $wsus.GetUpdateClassifications() | ? { $_.title -in (
      'Critical Updates',
      'Definition Updates',
      'Feature Packs',
      'Security Updates',
      'Service Packs',
      'Update Rollups',
      'Updates',
      'Upgrades') }
  $class_coll = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection
  $class_coll.AddRange($class)
  $rule.SetUpdateClassifications($class_coll)
  $rule.Enabled = $True
  $rule.Save()

  Write-Verbose "Run Default Approval Rule" -Verbose
  $rule.ApplyRule()
}
