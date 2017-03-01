#Requires -Modules xPSDesiredStateConfiguration

function Invoke-MDTInstallation {

  configuration InstallMDT
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

      package InstallWin10ADK
      {

        Name = "Windows Assessment and Deployment Kit - Windows 10"
        Path = "$WorkingDirectory\adksetup.exe"
        ProductId = ''
        Arguments = "/Features + /norestart /quiet /ceip off"
        Ensure = "Present"

      }

      localconfigurationmanager
      {
        RebootNodeIfNeeded = $True
      }

      package InstallMDT8443
      {

        Name = "Microsoft Deployment Toolkit (6.3.8443.1000)"
        Path = "$WorkingDirectory\MicrosoftDeploymentToolkit_x64.msi"
        ProductId = '{9547DE37-4A70-4194-97EA-ACC3E747254B}'
        Arguments = "/qn"
        Ensure = "Present"

      }

      localconfigurationmanager
      {
        RebootNodeIfNeeded = $True
      }

    }
  }

  InstallMDT -Servers localhost -OutputPath $WorkingDirectory -WorkingDirectory $WorkingDirectory

  Start-DscConfiguration -Path $WorkingDirectory -Wait -Verbose -Force -ErrorAction Stop
}
