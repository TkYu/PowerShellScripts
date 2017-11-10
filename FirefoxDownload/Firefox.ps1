if($ENV:OS -ne 'Windows_NT'){
	Write-Host 'Windows Plz!' -ForegroundColor Red
	return
}
if($PSVersionTable.PSVersion.Major -lt 3){
	Write-Host "I need PowerShell major version >= 3, Current is $($PSVersionTable.PSVersion.Major)" -ForegroundColor Red
	return
}

$installLocation = $env:ffdir
$local = $env:ffloc
$arch = $env:ffarch
$branch = $env:ffbranch
$url = 'https://www.mozilla.org/en-US/firefox/channel/desktop/'

#$local check
if ([string]::IsNullOrEmpty($local)){
	$local = (Get-UICulture).Name
}
#$arch check
if ([string]::IsNullOrEmpty($arch)){
	if($ENV:PROCESSOR_ARCHITECTURE -eq 'AMD64'){
		$arch = 'win64'
	}
	else{
		$arch = 'win'
	}
}
#$branch check
switch ($branch) 
{ 
	'nightly' {$branch = 'firefox-nightly-latest-l10n'} 
	'dev' {$branch = 'firefox-devedition-latest'} 
	'beta' {$branch = 'firefox-beta-latest'} 
	'esr' {$branch = 'firefox-esr-latest'} 
	default {$branch = 'firefox-latest'}
}
Write-Host "Current branch is $branch" -ForegroundColor Yellow
$url = "https://download.mozilla.org/?product=$branch-ssl&os=$arch&lang=$local"
if ($env:TEMP -eq $null) {
	$env:TEMP = Join-Path $installLocation 'temp'
}
#$installLocation check
if ([string]::IsNullOrEmpty($installLocation)){
	$installLocation = (Resolve-Path .\).Path
}

function Check-InstallLocation {
	
	Write-Host "Current install location is $installLocation"
	if((Test-Path $installLocation)){
		if(-Not ((Get-ChildItem $installLocation | Measure-Object).Count -eq 0)){
			Write-Host 'I need an empty folder!' -ForegroundColor Red
			return $false
		}
	}
	else{
		Write-Host "Create directory $installLocation" -ForegroundColor Yellow
		New-Item -ItemType Directory -Force -Path $installLocation | Out-Null
	}
	return $true
}

function Get-Downloader {
param (
  [string]$url
 )
  #WARNING: this function copy from chocolatey.org install.ps1
  $downloader = new-object System.Net.WebClient
  $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
  if ($defaultCreds -ne $null) {
	$downloader.Credentials = $defaultCreds
  }

  $withProxy = $env:ffWithProxy
  if ($withProxy -ne $null -and $withProxy -eq 'true') {
	# check if a proxy is required HTTP_PROXY=http://<proxy>:<port>
	$explicitProxy = $env:HTTP_PROXY
	if ($explicitProxy -ne $null -and $explicitProxy -ne '') {
	  # explicit proxy
	  $proxy = New-Object System.Net.WebProxy($explicitProxy, $true)
	  Write-Debug "Using explicit proxy server '$explicitProxy'."
	  $downloader.Proxy = $proxy

	} elseif (!$downloader.Proxy.IsBypassed($url)) {
	  # system proxy (pass through)
	  $creds = $defaultCreds
	  if ($creds -eq $null) {
		Write-Debug "Default credentials were null. Attempting backup method"
		$cred = get-credential
		$creds = $cred.GetNetworkCredential();
	  }
	  $proxyaddress = $downloader.Proxy.GetProxy($url).Authority
	  Write-Debug "Using system proxy server '$proxyaddress'."
	  $proxy = New-Object System.Net.WebProxy($proxyaddress)
	  $proxy.Credentials = $creds
	  $downloader.Proxy = $proxy
	}
  } else {
	Write-Debug "Explicitly bypassing proxy due to user environment variable"
	$downloader.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
  }
  return $downloader
}

function Download-String {
param (
  [string]$url
 )
	$downloader = Get-Downloader $url
	return $downloader.DownloadString($url)
}

function Download-File {
param (
  [string]$url,
  [string]$file
 )
	try{
		Write-Host "Downloading $url to $file" -ForegroundColor Yellow
		$downloader = Get-Downloader $url
		$downloader.DownloadFile($url, $file)
	}catch{
		Remove-Item $file
		Write-Host "Download $url fail!" -ForegroundColor Red
		return
	}
	Write-Host "Download finished" -ForegroundColor Green
}

function Extract-File {
param (
  [string]$fileName,
  [string]$dest
 )
	#WARNING: this function copy from chocolatey.org install.ps1
	Write-Host "Extract $fileName to $dest" -ForegroundColor Yellow
	$7zaExe = Join-Path $env:TEMP '7za.exe'
	if (-Not (Test-Path ($7zaExe))) {
		Write-Output "Downloading 7-Zip commandline tool prior to extraction."
		Download-File 'https://chocolatey.org/7za.exe' "$7zaExe"
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

function Remove-IfExists {
param (
  [string]$file
 )
	if(Test-Path $file){
		Remove-Item $file
	}
}

function Download-Firefox {
	$downloadFileName = Join-Path $installLocation 'installer.exe'
	Download-File $url $downloadFileName
	if(-Not (Test-Path $downloadFileName)){
		Write-Host 'Firefox Download Fail!' -ForegroundColor Red
		return
	}
	Extract-File $downloadFileName $installLocation
	Remove-IfExists "$installLocation\setup.exe"
	Move-Item "$installLocation\core\*" -Destination $installLocation
	Remove-IfExists "$installLocation\core"
	Remove-IfExists $downloadFileName
	Write-Host 'Firefox Download Finished' -ForegroundColor Green
}

if(Check-InstallLocation) {
	Download-Firefox
}