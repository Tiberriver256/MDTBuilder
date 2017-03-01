#Requires -Modules MicrosoftDeploymentToolkit

function Invoke-FinalMDTConfiguration {

  if (-not ((Get-PSDrive | select -ExpandProperty Name) -contains "DS001")) {
    New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root "$DeploymentShare" -Description "MDT Deployment Share" -NetworkPath "\\$($env:COMPUTERNAME)\DeploymentShare$" -Verbose -Force | add-MDTPersistentDrive -Verbose
  }

  if (-not (Test-Path "DS001:\Task Sequences\Windows 10\Deploy Windows 10 Enterprise x64")) {
    import-mdttasksequence -Path "DS001:\Task Sequences\Windows 10" -Name "Deploy Windows 10 Enterprise x64" -Template "Client.xml" -Comments "" -Id "HW0001" -Version "1.0" -OperatingSystemPath "DS001:\Operating Systems\ISO No Updates\Windows 10 Enterprise in Windows 10 x64 install.wim" -FullName "Haworth, Inc." -OrgName "Haworth, Inc." -HomePage "about:blank" -Verbose
  }

  if (-not (Test-Path "DS001:\Selection Profiles\WinPE_64Bit")) {
    New-Item -Path "DS001:\Selection Profiles" -enable "True" -Name "WinPE_64Bit" -Comments "This is a selection profile for drivers and applications that will be included in the boot image 64-bit WinPE Environment" -Definition "<SelectionProfile><Include path=`"Out-of-Box Drivers\WinPE_64Bit`" /></SelectionProfile>" -ReadOnly "False" -Verbose
  }
}
