#Requires -Modules xSmbShare

function Set-DFSInitialConfiguration {
  <# 
.SYNOPSIS 
    Creates file shares and installs necessary roles on remote PCS in preparation for DFS Replication for MDT

.DESCRIPTION 
    This script will do the following on each of the specified servers:
      1. Create an empty folder in the location of $DeploymentShare
      2. Create an SMB Share with the specified access levels
      3. Ensure the following roles are installed: FS-DFS-Replication and RSAT-DFS-Mgmt-Con
    
.PARAMETER RemoteServers
    These are the servers that will be configured

.PARAMETER DeploymentShar
    The file path the distribution share should be stored in

.PARAMETER GroupsWithAccess
    All groups here will be given read-only access to the remote distribution share. Changes should ONLY be made on the source server.

.PARAMETER WorkingDirectory
    The folder where the DSC MOF files will be stored for later removal.

.EXAMPLE 
    Invoke-DFSInitialConfiguration -RemoteServers ("SERVER01","SERVER02") -DeploymentShar "C:\DeploymentShar" -GroupsWithAccess ("Group1","Group2")
    This will prepare the two remote servers for replication by ensuring a shared folder exists at C:\DeploymentShar and that Group1 and Group2 both have read access to that shared folder.

.NOTES 
    Author: Adam Eaddy 
    Date: 16 December 2016 
    Last Modified: 18 December 2016
    Last Modified by: Micah Rairdon 
    
#>

  param(
    [Parameter(Mandatory = $true)]
    [string[]]$RemoteServers,
    [Parameter(Mandatory = $true)]
    [string]$DeploymentShare,
    [Parameter(Mandatory = $true)]
    [string[]]$GroupsWithAccess,
    [string]$WorkingDirectory = $PWD
  )

  Invoke-Command -ComputerName $RemoteServers -ScriptBlock { Install-Module xSMBShare -Force } -AsJob | Wait-Job

  configuration DFSInitialConfig {

    param(
      [Parameter(Mandatory = $true)]
      [string[]]$Servers
    )
    Import-DscResource -Name MSFT_xSmbShare
    node $Servers {

      file DeploymentShare {
        Ensure = "Present"
        Type = "Directory"
        DestinationPath = "$DeploymentShare"
      }

      xsmbshare DeploymentSMBShare {
        Ensure = "Present"
        Name = "DeploymentShare"
        Path = $DeploymentShare
        ReadAccess = $GroupsWithAccess

      }

      windowsfeature FS-DFS-Replication {
        Name = "FS-DFS-Replication"
        Ensure = "Present"
        IncludeAllSubFeature = $true
      }

      windowsfeature RSAT-DFS-Mgmt-Con {
        Name = "RSAT-DFS-Mgmt-Con"
        Ensure = "Present"
        IncludeAllSubFeature = $true
      }

    }
  }

  DFSInitialConfig -Servers $RemoteServers -OutputPath $WorkingDirectory

  Start-DscConfiguration -Path $WorkingDirectory -Wait -Verbose -Force -ErrorAction Stop

  Get-Item -Path $WorkingDirectory\*.MOF | Remove-Item -Force
}
