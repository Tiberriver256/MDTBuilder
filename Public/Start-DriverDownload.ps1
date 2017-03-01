function Start-DriverDownload {
  <# 
.SYNOPSIS 
    Downloads drivers from pre-built CSV to a destination location of your choice. 

.DESCRIPTION 
    The Start-DriverDownload script will create a folder tree in the destination location of the drivers you would like to download. It will unzip any ZIP files. 

.PARAMETER RawDriverDownloadLocation 
    The destination location you would like the raw folder structure of your drivers to be created in.

.PARAMETER CSVPath
    Path to the CSV that is used to download all of your drivers. Format for CSV should be (OS,Architecture,Make,Model,DownloadURL) 

.EXAMPLE 
    Start-DriverDownload -RawDriverDownloadLocation "\\myremoteserver\drivershare\" -CSVPath C:\My\DriversCSV.csv
    This will download all of the drivers in your CSV the location of \\myremoteserver\drivershare\$OS_$Architecture\$Make\$Model.

.NOTES 
    Author: Micah Rairdon 
    Date: 14 December 2016 
    Last Modified: 18 December 2016 
  
#>


  param(
    [Parameter(Mandatory = $true)]
    [string]$RawDriverDownloadLocation,
    [Parameter(Mandatory = $true)]
    [string]$CSVPath
  )

  $Drivers = Import-Csv $CSVPath



  foreach ($Driver in $Drivers) {

    $Make = $Driver.Make
    $Model = $Driver.Model
    $OS = $Driver.OS
    $Arch = $Driver.Architecture
    $URL = $Driver.DownloadURL

    $DestinationFolder = "$RawDriverDownloadLocation\$OS`_$Arch\$Make\$Model\"

    if (Test-Path $DestinationFolder) {
      Write-Host "Skipping downloading $OS $Arch $Make $Model as folder already exists"
    } else {
      New-Item $DestinationFolder -ItemType directory -Force
      Start-BitsTransfer -Asynchronous -Source $URL -Destination $DestinationFolder -TransferType Download
    }
  }

  while (Get-BitsTransfer | where { @( "Transferred","FatalError") -notcontains $_.JobState }) {

    $DownloadsRemaining = Get-BitsTransfer | where { @( "Transferred","Error") -notcontains $_.JobState }

    Write-Progress -Activity "Downloading drivers: $($DownloadsRemaining.count) remaining"

    Start-Sleep -Seconds 30

  }

  Get-BitsTransfer | Complete-BitsTransfer

  #Unzipping any drivers that came as a ZIP instead of a CAB
  Get-ChildItem -Path $RawDriverDownloadLocation -Filter *.zip -Recurse | ForEach-Object {
    Expand-Archive -Path $_.FullName -DestinationPath $_.DirectoryName -Force -ErrorAction Stop
    Remove-Item -Path $_.FullName
  }

}
