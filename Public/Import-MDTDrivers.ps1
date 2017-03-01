
#Requires -Modules MicrosoftDeploymentToolkit

function Import-MDTDrivers
{
  <# 
.SYNOPSIS 
    Imports Windows Drivers into Microsoft Deployment Toolkit.

.DESCRIPTION 
    The Import-MDTDrivers.ps1 script will duplicate a folder tree structure in Microsoft Deployment Toolkit and import the Drivers. 

.PARAMETER DriverPath 
    The fully qualified path to the folder that contains the device drivers you want to import. example: "C:\Downloads\Drivers". The default is the current folder in the shell. 

.PARAMETER PSDriveName 
    (Optional) MDT Persistent drive name example: "DS002". The default is the Persistent drive of the first Deployment Share. 

.PARAMETER DeploymentShare 
    (Optional) MDT Persistent drive path example: "D:\Depshare". The default is the first Deployment Share. 

.EXAMPLE 
    Import-MDTDrivers.ps1 
    This will import drivers from the current location to the driverstore of the first detected deploymentshare replicating the tree structure. 

.EXAMPLE 
    Import-MDTDrivers.ps1 -DriverPath C:\Downloads\Drivers -PSDriveName DS001 -DeploymentShare D:\DeploymentShare 
    This will import the device drivers into MDT from the source folder C:\Downloads\Drivers to the deployment share DS001 located at D:\DeploymentShare 

.NOTES 
    Author: Andrew Barnes 
    Date: 4 June 2012 
    Last Modified: 18 December 2016
    Last Modified By: Micah Rairdon 

.LINK 
    http://scriptimus.wordpress.com/2012/06/18/mdt-powershell-importing-drivers/ 
    
#>
  param(
    [string]$DriverPath = $PWD,# Device drivers path example: "C:\Downloads\Drivers" 
    [string]$PSDriveName,# MDT Persistent drive name example: "DS002" 
    [string]$DeploymentShare # MDT Persistent drive path example: "D:\Depshare" 
  )

  # \\ Detect First MDT PSDrive  
  if (!$PSDriveName) { $PSDriveName = (Get-MDTPersistentDrive)[0].Name }

  # \\ Detect First MDT Deployment Share 
  if (!$DeploymentShare) { $DeploymentShare = (Get-MDTPersistentDrive)[0].Path }

  $DSDriverPath = $PSDriveName + ':\Out-of-Box Drivers'
  $DSSelectionProfilePath = $PSDriveName + ':\Selection Profiles'

  # \\ Connect to Deployment Share 
  if (!(Get-PSDrive -Name $PSDriveName -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $PSDriveName -PSProvider MDTProvider -Root $DeploymentShare
  }
  # \\ Loop through folders and import Drivers 
  Get-ChildItem $DriverPath | ForEach-Object {
    $OS = $_
    if (!(Test-Path $DSDriverPath\$OS)) {
      New-Item -Path $DSDriverPath -enable "True" -Name $OS -ItemType "folder" -Verbose
    }

    if (!(Test-Path $DSSelectionProfilePath"\Drivers - "$OS)) {
      New-Item -Path $DSSelectionProfilePath -enable "True" -Name "Drivers - $OS" -Definition "<SelectionProfile><Include path=`"Out-of-Box Drivers\$OS`" /></SelectionProfile>" -ReadOnly "False" -Verbose
    }

    Get-ChildItem $_.FullName | ForEach-Object {
      $Make = $_
      if (!(Test-Path $DSDriverPath\$OS\$Make)) {
        New-Item -Path $DSDriverPath\$OS -enable "True" -Name $Make -ItemType "folder" -Verbose
      }
      Get-ChildItem $_.FullName | ForEach-Object {
        $Model = $_
        if (!(Test-Path $DSDriverPath\$OS\$Make\$Model)) {
          New-Item -Path $DSDriverPath\$OS\$Make -enable "True" -Name $Model -ItemType "folder" -Verbose
          import-mdtdriver -Path $DSDriverPath\$OS\$Make\$Model -SourcePath $_.FullName -Verbose
        }
      }
    }
  }
}
