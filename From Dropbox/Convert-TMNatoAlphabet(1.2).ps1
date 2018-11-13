Function Convert-TMNatoAlphabet {
##### ** THIS SCRIPT IS PROVIDED WITHOUT WARRANTY, USE AT YOUR OWN RISK **

<#
.SYNOPSIS
    Converts an alphanumeric string into the NATO Phonetic Alphabet equivalent.

.DESCRIPTION
    The advanced function will convert an alphanumeric string into the NATO phonetic alphabet.
	
.PARAMETER String
    This is the default, required parameter. It is the string that the advanced function will convert.

.EXAMPLE
    Convert-TMNatoAlphabet -String '12abc3'
    This example will convert the string, 12abc3, to its NATO phonetic alphabet equivalent. It will return, "One Two Alpha Bravo Charlie Three."

.EXAMPLE
    Convert-TMNatoAlphabet -String '1p2h3-cc'
    This example will attempt to convert the string, 1p2h3-cc, to its NATO phonetic alphabet equivalent. Since it contains an invalid character (-), it will return, "String contained illegal character(s)."

.EXAMPLE
    Convert-TMNatoAlphabet '1ph3cc'
    This example will convert the string, 1ph3cc, to its NATO phonetic alphabet equivalent. It will return, "One Papa Hotel Three Charlie Charlie."

.NOTES
    NAME: Convert-TMNatoAlphabet
    AUTHOR: Tommy Maynard
    LASTEDIT: 08/21/2014
    VERSION 1.1
        -Changed seperate alpha and numeric hashes into one, alphanumeric hash (numbers are being stored as strings)
    VERSION 1.2
        -Edited the logic that handles the conversion (no need for If and nested If - Initial If handles a-z 0-9 check)
        -Added string cleanup inside If statement
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0)]
        [string]$String
    )

    Begin {
        Write-Verbose -Message 'Creating alphanumeric hash table'
        $Hash = @{'A'=' Alpha ';'B'=' Bravo ';'C'=' Charlie ';'D'=' Delta ';'E'=' Echo ';'F'=' Foxtrot ';'G'=' Golf ';'H'=' Hotel ';'I'=' India ';'J'=' Juliet ';'K'=' Kilo ';'L'=' Lima ';'M'=' Mike ';'N'=' November ';'O'=' Oscar ';'P'=' Papa ';'Q'=' Quebec ';'R'=' Romeo ';'S'=' Sierra ';'T'=' Tango ';'U'=' Uniform ';'V'=' Victory ';'W'=' Whiskey ';'X'=' X-ray ';'Y'=' Yankee ';'Z'=' Zulu ';'0'=' Zero ';'1'=' One ';'2'=' Two ';'3'=' Three ';'4'=' Four ';'5'=' Five ';'6'=' Six ';'7'=' Seven ';'8'=' Eight ';'9'=' Nine '}
    
    } # End Begin

    Process {
        Write-Verbose -Message 'Checking string for illegal charcters'
        If ($String -match '^[a-zA-Z0-9]+$') {
            Write-Verbose -Message 'String does not have any illegal characters'
            $String = $String.ToUpper()

            Write-Verbose -Message 'Creating converted string'
            For ($i = 0; $i -le $String.Length; $i++) {
                [string]$Character = $String[$i]
                $NewString += $Hash.Get_Item($Character)
            }

            Write-Verbose -Message 'Cleaning up converted string'
            $NewString = ($NewString.Trim()).Replace('  ',' ')
            Write-Output $NewString
        } Else {
            Write-Output -Verbose 'String contained illegal character(s).'
        }
    } # End Process
} # End Function