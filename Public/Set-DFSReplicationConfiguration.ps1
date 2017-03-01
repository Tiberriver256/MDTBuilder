function Set-DFSReplicationConfiguration {
  <# 
.SYNOPSIS 
    Creates a hub and spoke DFS Replication group which is optimal for MDT with a larGe amount of distribution shares.

.DESCRIPTION 
    The primary will be used as the source. All spokes will be used as read-only distribution shares.

.PARAMETER Primary
    This computer will be used as the source computer for replicating the distribution share. This should be the same server Microsoft Deployment Toolkit is installed on.

.PARAMETER Spokes
    This is an array of server names where DFS should replicate a read-only copy of the primary.

.PARAMETER LocalDistributionSharePath
    The file path of the local distribution share that should be replicated to the spokes.

.PARAMETER ReplicationGroupName
    This is the name of the replication group that will be created. Defaults to: MDTReplicationGroup01

.PARAMETER ReplicationFolderName
    This is the name of the replication folder that will be created. Defaults to: MDTReplicationFolder01

.EXAMPLE 
    Set-DFSReplicationConfiguration -Primary $Env:ComputerName -Spokes ("SERVER01","SERVER02") -LocalDistributionSharePath "D:\DistributionShare"
    This will start a DFS-R replication group that uses the current computer as the primary source location with SERVER01 and SERVER02 being the spokes. The folder will be replicated to SERVER01 and SERVER02 as read-only.

.NOTES 
    Author: Micah Rairdon 
    Date: 18 December 2016 
    Last Modified: 18 December 2016 

.LINK
    https://blogs.technet.microsoft.com/filecab/2013/08/20/dfs-replication-in-windows-server-2012-r2-if-you-only-knew-the-power-of-the-dark-shell/

#>

  param(
    [Parameter(Mandatory = $true)]
    [string]$Primary,
    [Parameter(Mandatory = $true)]
    [string[]]$Spokes,
    [Parameter(Mandatory = $true)]
    [string]$LocalDistributionSharePath,
    [string]$ReplicationGroupName = "MDTReplicationGroup01",
    [string]$ReplicationFolderName = "MDTReplicationFolder01",
    [ValidateScript({
        if ($_ -match  '^(always|[0-9a-f]{672})$') {
          $True
        }
        else {
          throw "$_ is not a valid replications schedule. Choices are either 'Always' or a 96 character hex representation of the schedule. See the BandwidthDetails section of this TechNet article for more information: https://technet.microsoft.com/en-us/library/dn296568.aspx"
        }
      })]
    [string]$Schedule = "Always"
  )

  New-DfsReplicationGroup -GroupName $ReplicationGroupName |
  New-DfsReplicatedFolder -FolderName $ReplicationFolderName |
  Add-DfsrMember -MemberList ($spokes + $primary)

  foreach ($Spoke in $Spokes) {
    Add-DfsrConnection -GroupName $ReplicationGroupName `
       -SourceComputerName $primary `
       -DestinationComputerName $Spoke
  }

  #Determining staging quota size
  $QuotaSizeinMB = [int](
    (
      Get-ChildItem $LocalDistributionSharePath -Recurse |
      Sort-Object Length -Descending |
      Select-Object -First 32 |
      Measure-Object -Property Length -Sum
    ).Sum / 1MB
  )

  Set-DfsrMembership -GroupName $ReplicationGroupName `
     -FolderName $ReplicationFolderName `
     -ComputerName $primary `
     -ContentPath $LocalDistributionSharePath `
     -PrimaryMember $true `
     -StagingPathQuotaInMB $QuotaSizeinMB -Force

  Set-DfsrMembership -GroupName $ReplicationGroupName `
     -FolderName $ReplicationFolderName `
     -ComputerName $spokes `
     -ContentPath $LocalDistributionSharePath `
     -ReadOnly $true `
     -StagingPathQuotaInMB $QuotaSizeinMB –Force



  #Set all members of the group to use the group schedule instead of individual schedules
  Get-DfsrConnection -GroupName $ReplicationGroupName | 
    Set-DfsrConnectionSchedule -ScheduleType UseGroupSchedule



  if ($Schedule -eq "Always"){
    Set-DfsrGroupSchedule -GroupName $ReplicationGroupName -ScheduleType $Schedule
  } else {
    [hashtable]$Schedule = @{
      "Sunday" = $Schedule[0..95] -join ""
      "Monday" = $Schedule[96..191] -join ""
      "Tuesday" = $Schedule[192..287] -join ""
      "WednesDay" = $Schedule[288..383] -join ""
      "Thursday" = $Schedule[384..479] -join ""
      "Friday" = $Schedule[480..575] -join ""
      "Saturday" = $Schedule[576..671] -join ""
    }

    $DaysOfWeek = @(
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday"
    ) 
    
    for ($i = 0; $i -lt $DaysOfWeek.Count; $i++) {
      Set-DfsrGroupSchedule -GroupName $ReplicationGroupName -Day $i -BandWidthDetail $Schedule[$DaysOfWeek[$i]]
    }
    
  }
}