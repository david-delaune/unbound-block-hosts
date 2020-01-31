<#
.SYNOPSIS
    Generates a host file for Unbound DNS
.DESCRIPTION
    This powershell script parses a hosts file and converts it into the unbound local-data format.
.PARAMETER in_path
    Specifies the host file that you want to convert.
.PARAMETER out_path
    Specifies the output path for the result.
.EXAMPLE
    C:\PS> unbound-block-hosts.ps1 -in_path c:\hosts_file -out_path c:\output_file
    <Description of example>
.NOTES
    Author: David Delaune
    Date:   January 31, 2020
#>
Param	(
		[Alias("i")]
		[string]$in_path = "",
		[Alias("o")]
		[string]$out_path=[System.IO.Path]::Combine("./", [GUID]::NewGuid().ToString("N") + '.txt')
		)


$output = [System.IO.Path]::Combine("./", [GUID]::NewGuid().ToString("N") + '.txt')
$url_array =	@(
				"https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
				"https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt"
				"https://ssl.bblck.me/blacklists/hosts-file.txt"
				"https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt"
				"https://someonewhocares.org/hosts/zero/hosts"
				)

if(![string]::IsNullOrEmpty($in_path))
{
	$file = Get-Content $in_path -Encoding Ascii
	$output = $out_path
}
else
{
	$response = Read-Host -Prompt 'Would you like to download multiple hosts files and combine into one list? Y/N'
	if ($response -like 'Y')
	{
		$NLMType = [Type]::GetTypeFromCLSID('DCB00C01-570F-4A9B-8D69-199FDBA5723B')
		$INetworkListManager = [Activator]::CreateInstance($NLMType) 
		if($INetworkListManager.IsConnectedToInternet -ne $true)
		{
			Write-Output "Network List Manager says we are not connected to the internet."
			Write-Output "Attempting to download anyway..."
		}

		foreach ($url in $url_array)
		{
			Write-Output "Downloading: ${url}"
			$tmp = [System.IO.Path]::Combine("./", [GUID]::NewGuid().ToString("N") + '.txt')
			Invoke-WebRequest -Uri $url -OutFile $tmp
			Write-Output "Appending data to : ${output}"
			Get-Content -Path $tmp | Add-Content -Path $output
			Remove-Item $tmp
		}

		if([System.IO.File]::Exists($output) -and ((Get-Item $output).length -gt 0kb))
		{
			Write-Output "Download and amalgamation succeeded."
			$file = Get-Content $output -Encoding Ascii
		}
		else
		{
			Write-Output "Download failed."
			exit
		}
	}
}

$response = Read-Host -Prompt 'Would you like to generate a host list for unbound? Y/N'
if ($response -like 'Y')
{
	if([System.IO.File]::Exists($output))
	{
		foreach ($line in $file)
		{
			if ($line -notmatch '\#')
			{
				if ($line -notmatch '\:')
    			{
					$array = [regex]::Split($line, "\s+")
					if ($array.count -eq 2)
					{
            			$line = 'local-data: "' + $array[1] + ' A 0.0.0.0"'
            			Write-Host $line
            			Add-Content $out_path $line
					}
				}
			}
		}
	}
	else
	{
		Write-Output "Failed to open ${output}"
		exit
	}
}

$response = Read-Host -Prompt 'Would you like me to remove duplicate entries? Y/N'
if ($response -like 'Y')
{
	Get-Content $out_path | Sort-Object -Unique | Set-Content $out_path
}

Write-Output "All done. Your hosts file was written to: ${out_path}"