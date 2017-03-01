#Requires -Modules MicrosoftDeploymentToolkit,xSmbShare

function Invoke-InitialMDTConfiguration {
  #region Extracting ISOs and importing into MDT

  if (-not (Test-Path $DeploymentShare)) {
    New-Item -Path "$DeploymentShare" -ItemType directory
    New-SmbShare -Name "DeploymentShare$" -Path "$DeploymentShare" -FullAccess Administrators
  }

  if (-not (Test-Path "$DeploymentShare\Logs")) {
    New-Item -Path "$DeploymentShare\Logs" -ItemType directory
  }

  if (-not ((Get-PSDrive | Select-Object -ExpandProperty Name) -contains "DS001")) {
    New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root "$DeploymentShare" -Description "MDT Deployment Share" -NetworkPath "\\$($env:COMPUTERNAME)\DeploymentShare$" -Verbose -Force | add-MDTPersistentDrive -Verbose
  }

  if (-not (Test-Path "DS001:\Operating Systems")) {
    New-Item -Path "DS001:\Operating Systems" -enable "True" -Name "ISO No Updates" -Comments "This folder holds WIM files created from the ISOs. These have no Windows updates installed and no 3rd party software." -ItemType "folder" -Verbose
  }

  if (-not (Test-Path "DS001:\Operating Systems\ISO No Updates\Windows 10 Enterprise in Windows 10 x64 install.wim")) {
    $MountResult = Mount-DiskImage -ImagePath "$WorkingDirectory\SW_DVD5_WIN_ENT_10_1607_64BIT_English_MLF_X21-07102.ISO" -Passthru
    $DriveLetter = ($MountResult | Get-Volume).DriveLetter

    Write-Output "Importing Windows 10 Image"
    import-mdtoperatingsystem -Path "DS001:\Operating Systems\ISO No Updates" -SourcePath "$DriveLetter`:\" -DestinationFolder "Windows 10 x64" -Verbose

    Dismount-DiskImage -ImagePath "$WorkingDirectory\SW_DVD5_WIN_ENT_10_1607_64BIT_English_MLF_X21-07102.ISO"
  }
  #endregion

  #region Loading in a good customsettings.ini template

  $CustomSettingsTemplate = @"
[Settings]
Priority=Default
Properties=MyCustomProperty
[Default]
' // Logs
SLShare=\\$($env:COMPUTERNAME)\DeploymentShare$\Logs
' // Wizard Pages
SkipWizard=NO
SkipAppsOnUpgrade=NO
SkipDeploymentType=NO
SkipComputerName=NO
SkipDomainMembership=NO
' // OSDComputerName = 
' // and
' // JoinWorkgroup = 
' // or
' // JoinDomain = 
' // DomainAdmin = 
SkipUserData=NO
' // UDDir = 
' // UDShare = 
' // UserDataLocation = 
SkipComputerBackup=NO
' // BackupDir = 
' // BackupShare = 
' // ComputerBackupLocation = 
SkipTaskSequence=NO
' // TaskSequenceID="Task Sequence ID Here"
SkipProductKey=NO
' // ProductKey = 
' // Or
' // OverrideProductKey = 
' // Or
' // If using Volume license, no Property is required
SkipPackageDisplay=NO
' // LanguagePacks = 
SkipLocaleSelection=NO
' // KeyboardLocale = 
' // UserLocale = 
' // UILanguage = 
SkipTimeZone=NO
' // TimeZone = 
' // TimeZoneName = 
SkipApplications=NO
' // Applications
SkipAdminPassword=NO
' // AdminPassword
SkipCapture=NO
' // ComputerBackupLocation = 
SkipBitLocker=NO
' // BDEDriveLetter = 
' // BDEDriveSize = 
' // BDEInstall = 
' // BDEInstallSuppress = 
' // BDERecoveryKey = 
' // TPMOwnerPassword = 
' // OSDBitLockerStartupKeyDrive = 
' // OSDBitLockerWaitForEncryption = 
SkipSummary=NO
SkipFinalSummary=NO
SkipCredentials=NO
SkipRoles=NO
' // OSRoles
' // OSRoleServices
' // OSFeatures
SkipBDDWelcome=NO
SkipAdminAccounts=NO
' // Administrators = 
"@ | Out-File $DeploymentShare\Control\CustomSettings.ini -Encoding ASCII


  Update-MDTDeploymentShare -Path "DS001:" -Verbose

  #endregion

  #region Creating basic MDT folder structure
  if (-not (Test-Path "DS001:\Operating Systems\Base OS")) {
    New-Item -Path "DS001:\Operating Systems" `
       -enable "True" `
       -Name "Base OS" `
       -Comments "This will hold base WIM images. Fully patched but no scripts embedded or software installed" `
       -ItemType "folder" -Verbose
  }

  if (-not (Test-Path "DS001:\Operating Systems\Custom OS")) {
    New-Item -Path "DS001:\Operating Systems" `
       -enable "True" `
       -Name "Custom OS" `
       -Comments "This will hold customized WIM images. They may contain special software or scripts" `
       -ItemType "folder" -Verbose
  }

  if (-not (Test-Path "DS001:\Packages\Language Packs")) {
    New-Item -Path "DS001:\Packages" `
       -enable "True" `
       -Name "Language Packs" `
       -Comments "This is intended to hold language packs for the operatings systems" `
       -ItemType "folder" -Verbose
  }

  if (-not (Test-Path "DS001:\Packages\Language Packs\Windows 10")) {
    New-Item -Path "DS001:\Packages\Language Packs" `
       -enable "True" `
       -Name "Windows 10" `
       -Comments "This is intended to hold language packs for Windows 10" `
       -ItemType "folder" -Verbose
  }

  if (-not (Test-Path "DS001:\Packages\OS Patches")) {
    New-Item -Path "DS001:\Packages" `
       -enable "True" `
       -Name "OS Patches" `
       -Comments "This is intended to hold OS Patches for all OSes" `
       -ItemType "folder" -Verbose
  }

  if (-not (Test-Path "DS001:\Packages\OS Patches\Windows 10")) {
    New-Item -Path "DS001:\Packages\OS Patches" `
       -enable "True" `
       -Name "Windows 10" `
       -Comments "This is intended to hold OS Patches for Windows 10" `
       -ItemType "folder" -Verbose
  }

  if (-not (Test-Path "DS001:\Task Sequences\Windows 10")) {
    New-Item -Path "DS001:\Task Sequences" `
       -enable "True" `
       -Name "Windows 10" `
       -Comments "This is intended to hold the various task sequences for Windows 10 images" `
       -ItemType "folder" -Verbose
  }
  #endregion
}
