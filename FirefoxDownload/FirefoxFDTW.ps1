if($ENV:OS -ne 'Windows_NT'){
	Write-Host '請在 Windows 作業系統上使用!' -ForegroundColor Red
	return
}
if($PSVersionTable.PSVersion.Major -lt 3){
	Write-Host "請使用 PowerShell 主要版本 >= 3, 目前版本為 $($PSVersionTable.PSVersion.Major)" -ForegroundColor Red
	return
}
$installLocation = $env:ffdir
$local = $env:ffloc
$arch = $env:ffarch
$branch = $env:ffbranch

#$local check
if ([string]::IsNullOrEmpty($local)){
	$local = 'zh-TW'
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
Write-Host "目前設定分支為 " -NoNewline -ForegroundColor DarkYellow
Write-Host $branch -ForegroundColor Green
$url = "https://download.mozilla.org/?product=$branch-ssl&os=$arch&lang=$local"
#$installLocation check
if ([string]::IsNullOrEmpty($installLocation)){
	$installLocation = (Resolve-Path .\).Path
}
if ($env:TEMP -eq $null) {
	$env:TEMP = Join-Path $installLocation 'temp'
}
function Check-InstallLocation {
	if((Test-Path $installLocation)){
		if((Test-Path "$installLocation\firefox.exe")){
			return $false
		} else {
			if(-Not ((Get-ChildItem $installLocation | Measure-Object).Count -eq 0)){
				Write-Host '請在空的資料夾中執行!' -ForegroundColor Red
				return $false
			}
		}
	} else {
		Write-Host "建立目錄 $installLocation" -ForegroundColor Yellow
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
	   Write-Progress -activity "正在下載檔案 '$($url.split('/') | Select -Last 1)'" -status "下載進度 (已下載 $([System.Math]::Floor($downloadedBytes/1024))K , 檔案大小 $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
   }
   Write-Progress -activity "已完成 '$($url.split('/') | Select -Last 1)'  下載" -Status "Ready" -Completed
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
	Write-Host "正在解壓縮 $($fileName.split('\') | Select -Last 1)" -ForegroundColor Yellow
	$7zaExe = Join-Path $env:TEMP '7za.exe'
	if (-Not (Test-Path ($7zaExe))) {
		Write-Output "為了解壓縮 Firefox 安裝包，正在下載 7-Zip 命令列工具。"
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

	$errorMessage = "無法使用 7-Zip 解壓縮 Firefox 安裝包。 錯誤:"
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
		Write-Host '下載 Firefox 失敗!' -ForegroundColor Red
		return
	}
	Extract-File $downloadFileName $installLocation
	Remove-IfExists "$installLocation\setup.exe"
	Move-Item "$installLocation\core\*" -Destination $installLocation
	Remove-IfExists "$installLocation\core"
	Remove-IfExists $downloadFileName
	Write-Host '已完成 Firefox 下載' -ForegroundColor Green
}
function Check-FDInstallLocation {
	if(Test-Path $fddllpath){
		$hash = (Get-FileHash $fddllpath -Algorithm SHA1).Hash
	} else {
		$hash = ''
	}
	if($arch -eq 'x64'){
		if($hash -eq $FDJSON.link.x64.sha1){
			Write-Host "$fddll 已是最新版本!" -ForegroundColor Green
			return $false
		}
	} else {
		if($hash -eq $FDJSON.link.x86.sha1){
			Write-Host "$fddll 已是最新版本!" -ForegroundColor Green
			return $false
		}
	}
	Write-Host "$fddll 需要更新! 更新内容：" -NoNewline -ForegroundColor Yellow
	Write-Host $FDJSON.description -ForegroundColor Gray
	return $true
}
function Download-FireDoge {
	if($arch -eq 'win64'){
		Download-File $FDJSON.link.x64.url $fddllpath
		$hash = (Get-FileHash $fddllpath -Algorithm SHA1).Hash
		if($hash -ne $FDJSON.link.x64.sha1){
			Write-Host "SHA1 不相符!" -ForegroundColor Red
			return
		}
	}
	else{
		Download-File $FDJSON.link.x86.url $fddllpath
		$hash = (Get-FileHash $fddllpath -Algorithm SHA1).Hash
		if($hash -ne $FDJSON.link.x86.sha1){
			Write-Host "SHA1 不相符!" -ForegroundColor Red
			return
		}
	}
	$fdinipath = Join-Path $installLocation 'FireDoge.ini'
	if(-Not(Test-Path $fdinipath)){
		Download-File 'https://static.pzhacm.org/shuax/FireDogeTW.txt' $fdinipath
	}
	Write-Host 'FireDoge(by Shuax) 下載已完成' -ForegroundColor Green
}

if(Check-InstallLocation) {
	Download-Firefox
}
else{
	Write-Host 'Firefox 下載已略過(本機已存在)' -ForegroundColor Yellow
}

Write-Host ""
try{
	$FDJSON = Download-String 'https://api.pzhacm.org/iivb/fd.json' | ConvertFrom-Json
	if([string]::IsNullOrEmpty($FDJSON.description)){
		Write-Host '取得Firefox版本號碼失敗!' -ForegroundColor Red
		return
	}
	$fddll = $FDJSON.link.x64.url.Substring($FDJSON.link.x64.url.LastIndexOf("/") + 1)
	$fddllpath = Join-Path $installLocation $fddll
}catch{
	Write-Host '取得Firefox版本號碼失敗!' -ForegroundColor Red
	return
}
if(Check-FDInstallLocation) {
	Download-FireDoge
}
else{
	Write-Host 'FireDoge 下載已略過(本機已是最新版)' -ForegroundColor Yellow
}