if ($ENV:OS -ne 'Windows_NT') {
	Write-Host 'Windows Plz!' -ForegroundColor Red
	return
}
if ($PSVersionTable.PSVersion.Major -lt 3) {
	Write-Host "I need PowerShell major version >= 3, Current is $($PSVersionTable.PSVersion.Major)" -ForegroundColor Red
	return
}
$installLocation = $env:ggdir
$arch = $env:ggarch
#$branch = $env:ggbranch
$ggApi = 'https://api.pzhacm.org/iivb/cu.json'
$gcApi = 'https://api.pzhacm.org/iivb/gc.json'

if ($PSVersionTable.PSVersion.Major -lt 5) {
	if (-not ([System.Management.Automation.PSTypeName]'Branch').Type) {
		Add-Type -TypeDefinition @"
	   public enum Branch
	   {
		  Stable,
		  Beta,
		  Dev,
		  Canary
	   }
"@
	}
}
else {
	Enum Branch{
		Stable
		Beta
		Dev
		Canary
	}
}

#$arch check
if ([string]::IsNullOrEmpty($arch)) {
	if ($ENV:PROCESSOR_ARCHITECTURE -eq 'AMD64') {
		$arch = 'x64'
	}
	else {
		$arch = 'x86'
	}
}

$setDllExe = Join-Path $env:TEMP 'shuaxCAOdll32.exe'
$setDllUrl = 'https://cdn.jsdelivr.net/gh/TkYu/PowerShellScripts/tools/setdll32.bin'
if ($arch -eq 'x64') {
	$setDllExe = Join-Path $env:TEMP 'shuaxCAOdll64.exe'
	$setDllUrl = 'https://cdn.jsdelivr.net/gh/TkYu/PowerShellScripts/tools/setdll64.bin'
}

#$installLocation check
if ([string]::IsNullOrEmpty($installLocation)) {
	$installLocation = (Resolve-Path .\).Path
}

#$branch check
switch ($env:ggbranch) { 
	'canary' { $branch = [Branch]::Canary } 
	'dev' { $branch = [Branch]::Dev } 
	'beta' { $branch = [Branch]::Beta } 
	default { $branch = [Branch]::Stable }
}
#if([Enum]::Getvalues([Branch]) -contains $branch) {
#	$Branch = [Enum]::Parse([Type]"Branch",$branch)
#}
Write-Host "Current branch is " -NoNewline -ForegroundColor DarkYellow
Write-Host $branch -ForegroundColor Green
if ($env:TEMP -eq $null) {
	$env:TEMP = Join-Path $installLocation 'temp'
}
function Check-InstallLocation {
	if ((Test-Path $installLocation)) {
		if ((Test-Path "$installLocation\chrome.exe")) {
			$onlineVersion = [System.Version]($JSON.$branch.$arch.version)
			$localVersion = (Get-Item "$installLocation\chrome.exe").VersionInfo.FileVersion
			if ($onlineVersion -gt $localVersion) {
				Write-Host "Online version is " -NoNewline
				Write-Host $onlineVersion -NoNewline -ForegroundColor Green
				Write-Host ", Local version is " -NoNewline
				Write-Host $localVersion -NoNewline -ForegroundColor Yellow
				Write-Host ', let`s update!'
			}
			else {
				Write-Host "You have the latest version($localVersion)/$branch/$arch" -ForegroundColor Green
				return $false
			}
		}
		else {
			if (-Not ((Get-ChildItem $installLocation | Measure-Object).Count -eq 0)) {
				Write-Host 'I need an empty folder!' -ForegroundColor Red
				return $false
			}
		}
	}
 else {
		Write-Host "Create directory $installLocation" -ForegroundColor Yellow
		New-Item -ItemType Directory -Force -Path $installLocation | Out-Null
	}
	return $true
}

function Download-String {
	param (
  [string]$url
 )
	$downloader = new-object System.Net.WebClient
	$defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
	if ($defaultCreds -ne $null) {
		$downloader.Credentials = $defaultCreds
	}
	$downloader.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
	return $downloader.DownloadString($url)
}

function Download-File {
	param (
  [string]$url,
  [string]$targetFile
 )
	#https://blogs.msdn.microsoft.com/jasonn/2008/06/13/downloading-files-from-the-internet-in-powershell-with-progress/
	$uri = New-Object "System.Uri" "$url"
	$request = [System.Net.HttpWebRequest]::Create($uri)
	$request.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
	$request.Timeout = 200000 #200 second timeout 
	$response = $request.GetResponse()
	$totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
	$responseStream = $response.GetResponseStream()
	$targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
	$buffer = new-object byte[] 256KB
	$count = $responseStream.Read($buffer, 0, $buffer.length)
	$downloadedBytes = $count
	while ($count -gt 0) {
		$targetStream.Write($buffer, 0, $count)
		$count = $responseStream.Read($buffer, 0, $buffer.length)
		$downloadedBytes = $downloadedBytes + $count
		Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
	}
	Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'" -Status "Ready" -Completed
	$targetStream.Flush()
	$targetStream.Close()
	$targetStream.Dispose()
	$responseStream.Dispose()
}

function Extract-File {
	param (
  [string]$fileName,
  [string]$dest
 )
	#WARNING: this function copy from chocolatey.org install.ps1
	#Write-Host "Extract $fileName to $dest" -ForegroundColor Yellow
	Write-Host "Extracting $($fileName.split('\') | Select -Last 1)" -ForegroundColor Yellow
	$7zaExe = Join-Path $env:TEMP '7za.exe'
	if (-Not (Test-Path ($7zaExe))) {
		Write-Output "Downloading 7-Zip commandline tool prior to extraction."
		Download-File 'https://cdn.jsdelivr.net/gh/TkYu/PowerShellScripts/tools/7za.bin' "$7zaExe"
	}
	$params = "x -o`"$dest`" -bd -y `"$fileName`""
	$process = New-Object System.Diagnostics.Process
	$process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($7zaExe, $params)
	$process.StartInfo.RedirectStandardOutput = $true
	$process.StartInfo.UseShellExecute = $false
	$process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
	$process.Start() | Out-Null
	$process.BeginOutputReadLine()
	$process.WaitForExit()
	$exitCode = $process.ExitCode
	$process.Dispose()

	$errorMessage = "Unable to unzip package using 7zip. Error:"
	switch ($exitCode) {
		0 { break }
		1 { throw "$errorMessage Some files could not be extracted" }
		2 { throw "$errorMessage 7-Zip encountered a fatal error while extracting the files" }
		7 { throw "$errorMessage 7-Zip command line error" }
		8 { throw "$errorMessage 7-Zip out of memory" }
		255 { throw "$errorMessage Extraction cancelled by the user" }
		default { throw "$errorMessage 7-Zip signalled an unknown error (code $exitCode)" }
	}

}

function Set-Dll {
	param (
		[string]$fileName
	)
	if (-Not (Test-Path ($setDllExe))) {
		Write-Output "Downloading SetDll commandline tool prior to extraction."
		Download-File $setDllUrl "$setDllExe"
	}
	$bakfile = Join-Path $installLocation 'chrome.exe~'
	Remove-IfExists $bakfile
	$params = "/d:$fileName chrome.exe"
	$process = New-Object System.Diagnostics.Process
	$process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($setDllExe, $params)
	$process.StartInfo.WorkingDirectory = $installLocation
	$process.StartInfo.RedirectStandardOutput = $true
	$process.StartInfo.UseShellExecute = $false
	$process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
	$process.Start() | Out-Null
	$process.BeginOutputReadLine()
	$process.WaitForExit()
	$exitCode = $process.ExitCode
	$process.Dispose()
	if ($exitCode -eq 0) {
		Remove-IfExists $bakfile
	}
}

function Remove-IfExists {
	param (
  [string]$file
 )
	if (Test-Path $file) {
		Remove-Item $file
	}
}

function Download-Chrome {
	$chrome7z = Join-Path $installLocation 'chrome.7z'
	$url = $JSON.$branch.$arch.cdn
	$downloadFileName = Join-Path $installLocation $($url.split('/') | Select -Last 1)
	Download-File $url $downloadFileName
	if (-Not (Test-Path $downloadFileName)) {
		Write-Host 'Chrome Download Fail!' -ForegroundColor Red
		return
	}
	$hash = (Get-FileHash $downloadFileName -Algorithm SHA256).Hash
	if ($hash -ne $JSON.$branch.$arch.sha256) {
		Write-Host "SHA256 not match!" -ForegroundColor Red
		Remove-IfExists $downloadFileName
		return
	}
	Extract-File $downloadFileName $installLocation
	Extract-File $chrome7z $installLocation
	Remove-IfExists $chrome7z
	Move-Item "$installLocation\Chrome-bin\*" -Destination $installLocation
	Remove-IfExists "$installLocation\Chrome-bin"
	Remove-IfExists $downloadFileName
	Write-Host 'Chrome Download Finished' -ForegroundColor Green
}

function Check-GCInstallLocation {
	if (Test-Path $gcdllpath) {
		$hash = (Get-FileHash $gcdllpath -Algorithm SHA1).Hash
	}
 else {
		$hash = ''
	}
	if ($arch -eq 'x64') {
		if ($hash -eq $GCJSON.link.x64.sha1) {
			Write-Host "$gcdll is latest!" -ForegroundColor Green
			return $false
		}
	}
 else {
		if ($hash -eq $GCJSON.link.x86.sha1) {
			Write-Host "$gcdll is latest!" -ForegroundColor Green
			return $false
		}
	}
	Write-Host "$gcdll need update : " -NoNewline -ForegroundColor Yellow
	Write-Host $GCJSON.description -ForegroundColor Gray
	return $true
}

function Download-GreenChrome {
	if ($arch -eq 'x64') {
		Download-File $GCJSON.link.x64.url $gcdllpath
		$hash = (Get-FileHash $gcdllpath -Algorithm SHA1).Hash
		if ($hash -ne $GCJSON.link.x64.sha1) {
			Write-Host "SHA1 not match!" -ForegroundColor Red
			return
		}
	}
	else {
		Download-File $GCJSON.link.x86.url $gcdllpath
		$hash = (Get-FileHash $gcdllpath -Algorithm SHA1).Hash
		if ($hash -ne $GCJSON.link.x86.sha1) {
			Write-Host "SHA1 not match!" -ForegroundColor Red
			return
		}
	}
    if (Test-Path $gcdll) {
        Set-Dll $gcdll
    }
	Write-Host 'GreenChrome(by Shuax) download finished' -ForegroundColor Green
}

Write-Host ""
try {
	$JSON = Download-String $ggApi | ConvertFrom-Json
}
catch {
	Write-Host 'Get Chrome versions failed!' -ForegroundColor Red
	return
}
if (Check-InstallLocation) {
	Download-Chrome
}
else {
	Write-Host 'Chrome download skipped' -ForegroundColor Yellow
}

Write-Host ""
try {
	$GCJSON = Download-String $gcApi | ConvertFrom-Json
	if ([string]::IsNullOrEmpty($GCJSON.description)) {
		Write-Host 'Get GreenChrome versions failed!' -ForegroundColor Red
		return
	}
	$gcdll = $GCJSON.link.x64.url.Substring($GCJSON.link.x64.url.LastIndexOf("/") + 1)
	$gcdllpath = Join-Path $installLocation $gcdll
}
catch {
	Write-Host 'Get GreenChrome versions failed!' -ForegroundColor Red
	return
}
if (Check-GCInstallLocation) {
	Download-GreenChrome
}
else {
	Write-Host 'GreenChrome download skipped' -ForegroundColor Yellow
}
# $updaterpath = Join-Path $installLocation 'Update.cmd'
# if (-Not(Test-Path $updaterpath)) {
# 	$lower = $branch.ToString().ToLower()
# 	$updateps = "@SET `"ggbranch=$lower`" && @SET `"ggarch=$arch`" && " + ('@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy AllSigned -Command "iex ((New-Object System.Net.WebClient).DownloadString(''https://raw.githubusercontent.com/TkYu/PowerShellScripts/master/ChromeDownload/ChromeWithGreenChrome.ps1''))"')
# 	'@echo Checking Chrome update. Sit back and relax.', $updateps, "@pause" -join "`r`n" | Out-File -Encoding "Default" $updaterpath
# }

# SIG # Begin signature block
# MIIFlwYJKoZIhvcNAQcCoIIFiDCCBYQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnwzy+05XoS99wRGF8FeKBKUg
# 7W6gggMtMIIDKTCCAhWgAwIBAgIQE3U7au1O4rZEMExUKPt7LTAJBgUrDgMCHQUA
# MB8xHTAbBgNVBAMTFFRLUG93ZXJTaGVsbFRlc3RDZXJ0MB4XDTE3MTEwOTA3MTg0
# MVoXDTM5MTIzMTIzNTk1OVowHzEdMBsGA1UEAxMUVEtQb3dlclNoZWxsVGVzdENl
# cnQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCZwoClq3b+amIlFj53
# bpY/0DybAvJHI/mN9EJKGmxeW5DLo7AFon4bimtcC9uRFXzLgKADozHTQt2/2UJj
# kga7Hbdx5cSZZvXD3rRNhYs2gpUh6YEiuPzJVo1Da9HYFPHdBhX/doT3L4VKGiJd
# MUBqBzcfEOTCochd74dFbzwdQj+9132XlhSOpT6iEgAz7MoKXxcaYWDdChq4wGwb
# BGAA/cAdimH2jFIXx5qSs0/SNmkPzkS0rfkwA4c53paVuwjq3Mwj1emifMw1hV5x
# 0R50uyBDZwF6vWxnMYX9hdG8dNgQptecCP2EhfP9VUrwRM4tN0jH+FoWXYh+q68S
# PY4RAgMBAAGjaTBnMBMGA1UdJQQMMAoGCCsGAQUFBwMDMFAGA1UdAQRJMEeAEG9T
# Gh8zK8+owaVTRGAMetOhITAfMR0wGwYDVQQDExRUS1Bvd2VyU2hlbGxUZXN0Q2Vy
# dIIQE3U7au1O4rZEMExUKPt7LTAJBgUrDgMCHQUAA4IBAQAo0tjSpnncS34kqTut
# NdZxkyerzpwzbRJsrYYAI0WGErcPUIvKG8un4n50Dtm8b8KwWQUK9FQkNhSv0ULR
# QCT+Qrxm05IVNBhlbQfbjoYe9wGlXZdlxuUX++a/UemVG0WVOPpDc1PeI++8OnnY
# hNx1O5hRb7D+zT2eTAXtKYf6FKbj1BLaz9v6hVGpjOX3Ypi79Kx/zXCJC6B5laOK
# k4msoa2FHibX0L/UUKvHSMcbzTx1XfEbr2RXS+UE2b8nBzx4hE0OkU6wAQp/C/Kq
# L8P70+b3HpXznOhtCS1lGOJ9H+22TiIVIiGag6Nq61wHpcFaYhw6yyE/En9nB7Ur
# GhVCMYIB1DCCAdACAQEwMzAfMR0wGwYDVQQDExRUS1Bvd2VyU2hlbGxUZXN0Q2Vy
# dAIQE3U7au1O4rZEMExUKPt7LTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEK
# MAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3
# AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU945GWmkXCviqHamE
# wBFRG9AjGy0wDQYJKoZIhvcNAQEBBQAEggEALC18UZSEoFRSqQt/JIfvb3ADkJn3
# ce0Ehegw6o0SQI+x7/L2Ddhh69nklPkwb7d5WMQatrk5tgz+X6aGfcPEqKroKnMQ
# HBYAO8F48RcgAwVxSvzcgmGQPPPma8XPO+edekYirYQAj/2UaGElMH9/qJ3ImLR5
# tLwRL9dr+eD6vA5JHvf9ggbO6xpJTHOVGxtWUK1wczhNj54Kfewgj5ZbpJ8d2BVj
# vwTM9MdTCxHf2ApH0YpWVD/kTHQTMb2jfA+/ZDxBt38KDONP37tzfZf3g6Z8CniA
# mlRO9YyxL/xQtwDR5A57omiD6m/FgVcrPcSp/jR8XIaGLaOZSwPmmIqr/Q==
# SIG # End signature block
