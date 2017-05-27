#Requires -Modules xPSDesiredStateConfiguration

function Invoke-MDTPreparation {

  configuration PrepareMDTServer
  {

    param(
      [Parameter(Mandatory = $true)]
      [string[]]$Servers,
      [string]$WorkingDirectory
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    node $Servers
    {

      file Windows10ISO
      {
        Ensure = "Present" # You can also set Ensure to "Absent"
        Type = "File" # Default is "File".
        SourcePath = "http://care.dlservice.microsoft.com/dl/download/C/3/9/C399EEA8-135D-4207-92C9-6AAB3259F6EF/10240.16384.150709-1700.TH1_CLIENTENTERPRISEEVAL_OEMRET_X64FRE_EN-US.ISO"
        DestinationPath = "$WorkingDirectory\SW_DVD5_WIN_ENT_10_1607_64BIT_English_MLF_X21-07102.ISO"
      }

      xremotefile DownloadMDT8443
      {
        URI = "https://download.microsoft.com/download/3/3/9/339BE62D-B4B8-4956-B58D-73C4685FC492/MicrosoftDeploymentToolkit_x64.msi"
        DestinationPath = "$WorkingDirectory\MicrosoftDeploymentToolkit_x64.msi"
        MatchSource = $False
      }

      xremotefile DownloadWin10ADK
      {
        URI = "http://download.microsoft.com/download/8/1/9/8197FEB9-FABE-48FD-A537-7D8709586715/adk/adksetup.exe"
        DestinationPath = "$WorkingDirectory\adksetup.exe"
        MatchSource = $False
      }

    }

  }

  PrepareMDTServer -Servers localhost -OutputPath $WorkingDirectory -WorkingDirectory $WorkingDirectory

  Start-DscConfiguration -Path $WorkingDirectory -Wait -Verbose -Force -ErrorAction Stop
}
