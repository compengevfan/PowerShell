Function Check-PowerCLI
{
    Param(
    )

    if (!(Get-Module -Name VMware.VimAutomation.Core))
    {
	    write-host ("Adding PowerCLI...")
        Get-Module -Name VMware* -ListAvailable | Import-Module -Global
	    write-host ("Loaded PowerCLI.")
    }
}