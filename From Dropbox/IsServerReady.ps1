[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True)]
   [string]$ServerName
)

do
{
	write-host ("Not Ready...")
	sleep 30
}
while (!(Test-Connection $ServerName -quiet))

write-host ("Ready!")