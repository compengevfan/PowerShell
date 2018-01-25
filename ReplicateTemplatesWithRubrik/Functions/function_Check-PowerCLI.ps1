Function Check-PowerCLI
{
    Param(
    )

    if (!(Get-Module -Name VMware.VimAutomation.Core))
    {
        $PrevPath = Get-Location

	    write-host ("Adding PowerCLI...")
        if (Test-Path "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts")
        {
            cd "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts"
	        .\Initialize-PowerCLIEnvironment.ps1
        }
        if (Test-Path "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts")
        {
            cd "C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts"
            .\Initialize-PowerCLIEnvironment.ps1
        }

        cd $PrevPath

	    write-host ("Loaded PowerCLI.")
    }
}