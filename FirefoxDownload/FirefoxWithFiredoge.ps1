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
#$installLocation check
if ([string]::IsNullOrEmpty($installLocation)){
	$installLocation = (Resolve-Path .\).Path
}


if ($env:TEMP -eq $null) {
	$env:TEMP = Join-Path $installLocation 'temp'
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
  [string]$targetFile
 )
   #https://blogs.msdn.microsoft.com/jasonn/2008/06/13/downloading-files-from-the-internet-in-powershell-with-progress/
   $uri = New-Object "System.Uri" "$url"
   $request = [System.Net.HttpWebRequest]::Create($uri)
   $request.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
   $request.Timeout = 60000 #60 second timeout 
   $response = $request.GetResponse()
   $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
   $responseStream = $response.GetResponseStream()
   $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
   $buffer = new-object byte[] 256KB
   $count = $responseStream.Read($buffer,0,$buffer.length)
   $downloadedBytes = $count
   while ($count -gt 0)
   {
	   $targetStream.Write($buffer, 0, $count)
	   $count = $responseStream.Read($buffer,0,$buffer.length)
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
else{
	Write-Host 'Firefox Download Skipped' -ForegroundColor Yellow
}

$JSON = Download-String 'https://static.pzhacm.org/shuax/fd/fd.json' | ConvertFrom-Json
if([string]::IsNullOrEmpty($JSON.description)){
	Write-Host "Get Firedoge version fail!" -ForegroundColor Red
	return;
}
Write-Host "Current Firedoge version is $($JSON.version)" -ForegroundColor Gray
Write-Host $JSON.description -ForegroundColor Gray
$fddll = $JSON.link.x64.url.Substring($JSON.link.x64.url.LastIndexOf("/") + 1)
$fddllpath = Join-Path $installLocation $fddll
if(Test-Path $fddllpath){
	$hash = (Get-FileHash $fddllpath -Algorithm SHA1).Hash
}else{
	$hash = ''
}
if($arch -eq 'win64'){
	if($hash -eq $JSON.link.x64.sha1){
		Write-Host "$fddll is latest!" -ForegroundColor Green
	}else{
		Download-File $JSON.link.x64.url $fddllpath
		$hash = (Get-FileHash $fddllpath -Algorithm SHA1).Hash
		if($hash -ne $JSON.link.x64.sha1){
			Write-Host "SHA1 not match!" -ForegroundColor Red
			return;
		}
	}
}
else{
	if($hash -eq $JSON.link.x86.sha1){
		Write-Host "$fddll is latest!" -ForegroundColor Green
	}else{
		Download-File $JSON.link.x86.url $fddllpath
		$hash = (Get-FileHash $fddllpath -Algorithm SHA1).Hash
		if($hash -ne $JSON.link.x86.sha1){
			Write-Host "SHA1 not match!" -ForegroundColor Red
			return;
		}
	}
}

Write-Host 'Firedoge(by Shuax) Download Finished' -ForegroundColor Green
