Add-Type -AssemblyName System.Windows.Forms
#Add-Type -AssemblyName PresentationCore, PresentationFramework
[System.Windows.Forms.Application]::EnableVisualStyles()
$MethodDefinition = @'
[DllImport("user32.dll", CharSet = CharSet.None, ExactSpelling = false)]
public static extern bool SetProcessDPIAware();
'@
$User32 = Add-Type -MemberDefinition $MethodDefinition -Name 'user32' -Namespace 'user32' -PassThru
$_ = $User32::SetProcessDPIAware()

#region Prepare
try {
    $acp = $env:gcupdateACP -as [int]
}
catch {
    return
}
if ($acp -eq 936) {
    $bundle = Data {
        #culture="zh-CN"
        ConvertFrom-StringData @'
MSG_TITLE = 找到新版本
MSG_ERROR_TITLE = 出错
MSG_SHA1_MISSMATCH = SHA1校验出错！({0} != {1})
MSG_EXTRACT_ERROR = 解压安装包失败(错误码={0})，是否需要打开下载页(https://tools.shuax.com/chrome)自行下载更新包更新？
MSG_CHROME_UPDATE = 当前谷歌浏览器有新版本！（线上版本{0} / 本地版本{1}）要开始准备更新吗？
MSG_GC_UPDATE = 当前GreenChrome有新版本！（线上版本{0} / 本地版本{1}）\n更新内容：{2}\n要开始准备更新吗？
MSG_G2G = 更新包已下载完成，是否立即启动更新？取消的话则会在下次启动时更新。
MSG_DOWNLOAD_FAIL = 下载安装包失败，是否需要打开下载页(https://tools.shuax.com/chrome)自行下载更新包更新？
'@
    }
}
elseif ($acp -eq 950) {
    $bundle = Data {
        #culture="zh-TW"
        ConvertFrom-StringData @'
MSG_TITLE = 更新吧
MSG_ERROR_TITLE = 出錯
MSG_SHA1_MISSMATCH = SHA1不相符！({0} != {1})
MSG_EXTRACT_ERROR = 解壓縮安裝包失敗(返回碼={0})，是否需要打开下载页(https://tools.shuax.com/chrome)自行下载更新包更新？
MSG_CHROME_UPDATE = 当前Chrome有新版本！（線上版本為{0} / 本機版本為{1}）是否立即開始準備更新？
MSG_GC_UPDATE = 当前GreenChrome有新版本！（線上版本為{0} / 本機版本為{1}）\n更新内容：{2}\n是否立即開始準備更新？
MSG_G2G = 更新包已下載完成，是否立即啟動更新？取消的話則會在下次啟動時更新。
MSG_DOWNLOAD_FAIL = 下載安裝包失敗，是否需要打開下載頁(https://tools.shuax.com/chrome)自行下載更新包更新？
'@
    }
}
else {
    $bundle = Data {
        ConvertFrom-StringData @'
MSG_TITLE = New Version
MSG_ERROR_TITLE = Error
MSG_SHA1_MISSMATCH = SHA1 Miss Match! ({0} != {1})
MSG_EXTRACT_ERROR = Extract fail(return code={0})! goto https://tools.shuax.com/chrome update by your self?
MSG_CHROME_UPDATE = New Chrome version was founded! (Current={0},NewVersion={1}) . Start Update?
MSG_GC_UPDATE = New GreenChrome version was founded! (Current={0},NewVersion={1})\n{2}\n Start Update?
MSG_G2G = Update package downloaded, Start update right now?
MSG_DOWNLOAD_FAIL = Download fail! goto https://tools.shuax.com/chrome update by your self?
'@
    }
}

if ([string]::IsNullOrEmpty($env:gcupdatePATH)) {
    return
}

$ggApi = 'https://api.pzhacm.org/iivb/cu.json'
$gcApi = 'https://api.pzhacm.org/iivb/gc.json'

$installLocation = $env:gcupdatePATH.Trim()
$7zaExe = Join-Path $env:TEMP '7za.exe'
$archInt = $env:gcupdateARCH -as [int]
$arch = 'x86'
$setDllExe = Join-Path $env:TEMP 'shuaxCAOdll32.exe'
$setDllUrl = 'https://cdn.jsdelivr.net/gh/TkYu/PowerShellScripts/tools/setdll32.bin'
if ($archInt -eq 1) {
    $arch = 'x64'
    $setDllExe = Join-Path $env:TEMP 'shuaxCAOdll64.exe'
    $setDllUrl = 'https://cdn.jsdelivr.net/gh/TkYu/PowerShellScripts/tools/setdll64.bin'
}
$currentVersion = $env:gcupdateCV -as [version]
$chromeVersion = $env:gcupdateGV -as [version]

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

switch ($env:gcupdateBCH.ToLower()) { 
    'canary' { $branch = [Branch]::Canary } 
    'dev' { $branch = [Branch]::Dev } 
    'beta' { $branch = [Branch]::Beta } 
    default { $branch = [Branch]::Stable }
}

#endregion Prepare

#region Methods
function Get-HTTPContentString {
    param (
        [string]$url
    )
    $downloader = new-object System.Net.WebClient
    $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
    if ($defaultCreds -ne $null) {
        $downloader.Credentials = $defaultCreds
    }
    return $downloader.DownloadString($url)
}
function Get-HTTPFile {
    param (
        [string]$url,
        [string]$filePath
    )
    #bits
    try {
        $job = Start-BitsTransfer -Source $url -Destination $filePath -Asynchronous
        While ($job.JobState -eq "Transferring") {
            Start-Sleep -Seconds 1
        }
        If ($job.InternalErrorCode -ne 0) {
            Remove-IfExists $filePath
        }
        Complete-BitsTransfer -BitsJob $job
    }
    catch {
        Remove-IfExists $filePath
    }
    #webclient
    if (-Not (Test-Path ($filePath))) {
        try {
            $downloader = new-object System.Net.WebClient
            $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
            if ($defaultCreds -ne $null) {
                $downloader.Credentials = $defaultCreds
            }
            $downloader.DownloadFile($url, $filePath)
        }
        catch {
            Remove-IfExists $filePath
        }
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

function Start-Extract {
    param (
        [string]$fileName,
        [string]$dest
    )
    if (-Not (Test-Path($7zaExe))) {
        Get-HTTPFile 'https://cdn.jsdelivr.net/gh/TkYu/PowerShellScripts/tools/7za.bin' $7zaExe
    }
    if (-Not (Test-Path($7zaExe))) {
        return
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

    if ($exitCode -ne 0) {
        Remove-IfExists $chrome7z
        Remove-IfExists $cbFolder
        $msg = $bundle['MSG_EXTRACT_ERROR'] -f $exitCode
        $result = [System.Windows.Forms.MessageBox]::Show($msg, $bundle['MSG_ERROR_TITLE'], 'YesNo', 'Error')
        if ($result -eq 'Yes') {
            Start-Process 'https://tools.shuax.com/chrome/'
        }
    }
}

function Search-GCUpdate {
    foreach ($file in Get-ChildItem -Path $installLocation -Filter *.gcupdate) {
        if ($file.VersionInfo.ProductName -eq 'GreenChrome') {
            return $file.Name
        }
    }
    return $null
}

function Start-Update {
    Remove-IfExists $chrome7z
    if (-Not (Test-Path($setDllExe))) {
        Get-HTTPFile $setDllUrl $setDllExe
    }
    if (Test-Path $chromeDownloadFile) {
        $updateFileVersion = (Get-Item $chromeDownloadFile).VersionInfo.FileVersion.ToString()
        if (-Not(Test-Path $cbFolder) -Or -Not(Test-Path (Join-Path $cbFolder 'chrome.exe')) -Or -Not(Test-Path (Join-Path $cbFolder $updateFileVersion))) {
            Remove-IfExists $cbFolder
            Start-Extract $chromeDownloadFile $installLocation
            Start-Extract $chrome7z $installLocation
            Remove-IfExists $chrome7z
        }
        if (!(Test-Path (Join-Path $cbFolder 'chrome.exe')) -Or !(Test-Path (Join-Path $cbFolder $updateFileVersion))) {
            return
        }
    }
    Start-Process powershell.exe -ArgumentList "-NoProfile -InputFormat None -ExecutionPolicy AllSigned -Command iex ((New-Object System.Net.WebClient).DownloadString('https://cdn.jsdelivr.net/gh/TkYu/PowerShellScripts/ChromeDownload/GCupdate.ps1'))"
}
#endregion Methods

if ($ENV:OS -ne 'Windows_NT') {
    return
}
if ($PSVersionTable.PSVersion.Major -lt 3) {
    return
}
$chromeDownloadFile = Join-Path $installLocation 'update.exe'
$chrome7z = Join-Path $installLocation 'chrome.7z'
$cbFolder = Join-Path $installLocation 'Chrome-bin'
$gcu = Search-GCUpdate
if ((Test-Path $chromeDownloadFile) -Or ($null -ne $gcu)) {
    Start-Update
    return
}
#chrome
try {
    $JSON = Get-HTTPContentString $ggApi | ConvertFrom-Json
}
catch {
    return
}
$onlineVersion = [System.Version]($JSON.$branch.$arch.version)
if ($onlineVersion -gt $chromeVersion) {
    $msg = $bundle['MSG_CHROME_UPDATE'] -f $onlineVersion, $chromeVersion
    $result = [System.Windows.Forms.MessageBox]::Show($msg, $bundle['MSG_TITLE'], 'OKCancel', 'Question')
    if ($result -eq 'OK') {
        $url = $JSON.$branch.$arch.cdn
        Get-HTTPFile $url $chromeDownloadFile
        if (Test-Path ($chromeDownloadFile)) {
            $g2g = [System.Windows.Forms.MessageBox]::Show($bundle['MSG_G2G'], $bundle['MSG_TITLE'], 'OKCancel', 'Question')
            if ($g2g -eq 'OK') {
                Start-Update
            }
        }
        else {
            $result = [System.Windows.Forms.MessageBox]::Show($bundle['MSG_DOWNLOAD_FAIL'], $bundle['MSG_ERROR_TITLE'], 'YesNo', 'Error')
            if ($result -eq 'Yes') {
                Start-Process 'https://tools.shuax.com/chrome/'
            }
        }
    }
    return
}
#greenchrome
try {
    $GCJSON = Get-HTTPContentString $gcApi | ConvertFrom-Json
    if ([string]::IsNullOrEmpty($GCJSON.description)) {
        return
    }
}
catch {
    return
}
$onlineGCVersion = [System.Version]($GCJSON.version)
if ($onlineGCVersion -gt $currentVersion) {
    $msg = $bundle['MSG_GC_UPDATE'] -f $onlineGCVersion, $currentVersion, $GCJSON.description
    $result = [System.Windows.Forms.MessageBox]::Show($msg, $bundle['MSG_TITLE'], 'OKCancel', 'Question')
    if ($result -eq 'OK') {
        $url = $GCJSON.link.$arch.url
        $gcdll = $GCJSON.link.$arch.url.Substring($GCJSON.link.$arch.url.LastIndexOf("/") + 1)
        $gcdllpath = Join-Path $installLocation "$gcdll.gcupdate"
        Get-HTTPFile $url $gcdllpath
        if (Test-Path $gcdllpath) {
            $hash = (Get-FileHash $gcdllpath -Algorithm SHA1).Hash
            if ($hash -ne $GCJSON.link.$arch.sha1) {
                $msg = $bundle['MSG_SHA1_MISSMATCH'] -f $hash , $GCJSON.link.$arch.sha1
                $_ = [System.Windows.Forms.MessageBox]::Show($msg, $bundle['MSG_ERROR_TITLE'], 'YesNo', 'Error')
                return
            }
            $g2g = [System.Windows.Forms.MessageBox]::Show($bundle['MSG_G2G'], $bundle['MSG_TITLE'], 'OKCancel', 'Question')
            if ($g2g -eq 'OK') {
                Start-Update
            }
        }
    }
}
# SIG # Begin signature block
# MIIFlwYJKoZIhvcNAQcCoIIFiDCCBYQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJU/tZ4k9XHnnNhCfuNugpcvI
# C1SgggMtMIIDKTCCAhWgAwIBAgIQE3U7au1O4rZEMExUKPt7LTAJBgUrDgMCHQUA
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
# AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUfYlfZCQXj0mQEzCI
# qo24MpP+e9gwDQYJKoZIhvcNAQEBBQAEggEAMjJ/3L7UYMRXQwQAIero35JM5OBM
# y04Yri+ZwGaRtNcAR64P9peleIHP021mt8/wU6AxA69myFjNiuySOkTm7y37xb0+
# EyXHJbXpH9AdKy5bMxFaMNi5gcb5ubjIdUn/MBTmVE0EmOhNQWcOvb4VgrvhxR5M
# yBbIYYAqtuy1c/yv9OPPyPtoIA8aQ3xYICkxD9r2ZqI1h4IJn6y+bjsgbqa2g1YF
# Y01SluqkMPAH0csEj8bWUd6JEdf/uGDVQye8XmbqKjK7TVixUVn13ZZZMDy6q4f0
# VQQLcQZyd7GYJPg7/svxtM12nWFlK55yFBUeDb9gK2PCHfQBNn6XrJ/gjw==
# SIG # End signature block
