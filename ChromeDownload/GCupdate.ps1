#region Prepare
$acp = $env:gcupdateACP -as [int]
if ($acp -eq 936) {
    $bundle = Data {
        #culture="zh-CN"
        ConvertFrom-StringData @'
        MSG_WAIT_PROGRESS_TITLE = 正在准备更新，坐和放宽
        NEED_WINDOWS = 请使用Windows系统运行!
        NEED_PSVERSION = 需要 PowerShell 的主要版本 >= 3, 目前版本为 {0}
        MSG_PRESS_ANYKEY_EXIT = 按任意键退出 ...
        MSG_PRESS_ANYKEY_START = 更新完成，按任意键启动Chrome ...
        NOT_FOUND = 找不到路径：{0}
        MSG_G2G = 您的浏览器将会在更新后重新启动，坐和放宽
        MSG_KILL_FAIL = 无法结束Chrome.exe，可能是权限问题
        MSG_RDY_KILL = 即将开始进行更新，更新过程中会自动结束Chrome并在更新完成后重新启动\n重启后可以根据浏览器右上方的提示恢复关闭前的会话（也可以直接按下Ctrl+Shift+T）\n按下任意键以启动更新，或者直接点击关闭按钮退出
'@
    }
}
elseif ($acp -eq 950) {
    $bundle = Data {
        #culture="zh-TW"
        ConvertFrom-StringData @'
        MSG_WAIT_PROGRESS_TITLE = 正在準備更新，坐和放寬
        NEED_WINDOWS = 請使用Windows系統運行!
        NEED_PSVERSION = 需要 PowerShell 的主要版本 >= 3, 目前版本為 {0}
        MSG_PRESS_ANYKEY_EXIT = 按任意鍵退出 ...
        MSG_PRESS_ANYKEY_START = 更新完成，按任意鍵啟動Chrome ...
        NOT_FOUND = 找不到路徑：{0}
        MSG_G2G = 您的瀏覽器將會在更新後重新啟動，坐和放寬
        MSG_KILL_FAIL = 無法結束Chrome.exe，可能是權限問題
        MSG_RDY_KILL = 即將開始進行更新，更新過程中會自動結束Chrome並在更新完成後重新啟動\n重啟後可以根據瀏覽器右上方的提示恢復關閉前的會話（也可以直接按下Ctrl+Shift+T） \n按下任意鍵以啟動更新，或者直接點擊關閉按鈕退出
'@
    }
}
else {
    $bundle = Data {
        #culture="en-US"
        ConvertFrom-StringData @'
        MSG_WAIT_PROGRESS_TITLE = Sit back and relax
        NEED_WINDOWS = Windows Plz!
        NEED_PSVERSION = I need PowerShell major version >= 3, Current is {0}
        MSG_PRESS_ANYKEY_EXIT = Press any key to exit . . . 
        MSG_PRESS_ANYKEY_START = Done! Press any key to start chrome . . . 
        MSG_G2G = Your browser will restart after update, sit back and relax
        MSG_KILL_FAIL = Cant murder chrome.exe
        MSG_RDY_KILL = Chrome will be killed during the update process and restart after the update is complete.\nAfter restarting you can restore the session. (Ctrl+Shift+T)\nPress any key to start update, or close this window to exit
        NOT_FOUND = {0} 404 Not Found!
'@
    }
}
if ([string]::IsNullOrEmpty($env:gcupdatePATH)) {
    return
}
$installLocation = $env:gcupdatePATH.Trim()
$archInt = $env:gcupdateARCH -as [int]
$setDllExe = Join-Path $env:TEMP 'shuaxCAOdll32.exe'
if ($archInt -eq 1) {
    $setDllExe = Join-Path $env:TEMP 'shuaxCAOdll64.exe'
}
$chromeDownloadFile = Join-Path $installLocation 'update.exe'
$cbFolder = Join-Path $installLocation 'Chrome-bin'
$chromeExe = Join-Path $installLocation 'chrome.exe'
$chromeproxyExe = Join-Path $installLocation 'chrome_proxy.exe'

#endregion Prepare


#region Function
function Exit-Script {
    param (
        [string]$warning
    )
    Write-Host $warning -ForegroundColor Red
    Write-Host $bundle['MSG_PRESS_ANYKEY_EXIT']
    $_ = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Break Script
}
function Remove-IfExists {
    param (
        [string]$file
    )
    if (Test-Path $file) {
        Remove-Item $file
    }
}

function Search-GCDll {
    foreach ($file in Get-ChildItem -Path $installLocation -Filter *.dll) {
        if ($file.VersionInfo.ProductName -eq 'GreenChrome') {
            return $file.Name
        }
    }
    return $null
}
function Search-GCUpdate {
    foreach ($file in Get-ChildItem -Path $installLocation -Filter *.gcupdate) {
        if ($file.VersionInfo.ProductName -eq 'GreenChrome') {
            return $file.Name
        }
    }
    return $null
}
function Set-Dll {
    param (
        [string]$fileName
    )
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

function Search-InstallPack {
    $gcUpdate = Search-GCUpdate
    if ($null -ne $gcUpdate) {
        return $true
    }
    if (!(Test-Path $cbFolder)) {
        return $false
    }
    $cbChromeExe = Join-Path $cbFolder 'chrome.exe'
    $updateFileVersion = Join-Path $cbFolder (Get-Item $cbChromeExe).VersionInfo.FileVersion.ToString()
    if ((Test-Path $cbFolder) -And (Test-Path $cbChromeExe) -And (Test-Path $updateFileVersion)) {
        return $true
    }
    return $false
}
function Start-UpdateGC {
    $gcUpdate = Search-GCUpdate
    $gcDll = Search-GCDll
    if ($null -eq $gcUpdate) {
        return
    }
    $gcUpdatePath = Join-Path $installLocation $gcUpdate
    $gcNewDllPath = Join-Path $installLocation ($gcUpdate -Replace ".gcupdate", "")
    $gcoldDllPath = Join-Path $installLocation $gcDll
    $gcBakPath = Join-Path $installLocation "$gcDll.bak"
    Remove-IfExists $gcBakPath
    Move-Item $gcoldDllPath $gcBakPath
    Move-Item $gcUpdatePath $gcNewDllPath
}
function Start-UpdateChrome {
    if (!(Test-Path $cbFolder)) {
        return
    }
    $chromeOld = Join-Path $installLocation 'chrome_old.exe'
    if ((Test-Path $chromeOld)) {
        $oldVersionDir = Join-Path $installLocation (Get-Item $chromeOld).VersionInfo.FileVersion
        if ((Test-Path $oldVersionDir)) {
            Remove-Item $oldVersionDir -Force -Recurse
        }
        Remove-Item $chromeOld -Force
    }
    $chromeproxyOld = Join-Path $installLocation 'chrome_proxy_old.exe'
    if ((Test-Path $chromeproxyOld)) {
        Remove-Item $chromeproxyOld -Force
    }
    Move-Item $chromeExe $chromeOld
    if ((Test-Path $chromeproxyExe)) {
        Move-Item $chromeproxyExe $chromeproxyOld
    }
    Move-Item "$cbFolder\*" -Destination $installLocation
    Remove-IfExists $cbFolder
    Remove-IfExists $chromeDownloadFile
    $gcDll = Search-GCDll
    if ($null -ne $gcDll) {
        Set-Dll $gcDll
    }
}
#endregion Function

$host.ui.RawUI.WindowTitle = $bundle['MSG_WAIT_PROGRESS_TITLE']

#check env
if ($ENV:OS -ne 'Windows_NT') {
    Exit-Script $bundle['NEED_WINDOWS']
    return
}

if ($PSVersionTable.PSVersion.Major -lt 3) {
    Exit-Script ($bundle['NEED_PSVERSION'] -f $($PSVersionTable.PSVersion.Major))
    return
}

if (!(Test-Path $installLocation)) {
    Exit-Script ($bundle['NOT_FOUND'] -f $installLocation)
    return;
}

if (!(Search-InstallPack)) {
    Exit-Script ($bundle['NOT_FOUND'] -f 'Installer')
}

if (!(Test-Path $setDllExe)) {
    Exit-Script ($bundle['NOT_FOUND'] -f 'SetDll')
}

#good to go

#kill chrome.exe
$chromeProcess = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $chromeExe }
if ($chromeProcess) {
    Write-Host $bundle['MSG_RDY_KILL'] -ForegroundColor Yellow
    $_ = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown");
    $chromeProcess | Stop-Process
    Start-Sleep 1
}
else {
    Write-Host $bundle['MSG_G2G'] -ForegroundColor Yellow
}
$chromeProcess = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $chromeExe }
if ($chromeProcess) {
    Exit-Script $bundle['MSG_KILL_FAIL']
    return
}
#do update
Start-UpdateGC
Start-UpdateChrome
#restart
Write-Host $bundle['MSG_PRESS_ANYKEY_START'] -ForegroundColor Green
$_ = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
if ((Test-Path $chromeExe)) {
    Start-Process -FilePath $chromeExe
}
# SIG # Begin signature block
# MIIFlwYJKoZIhvcNAQcCoIIFiDCCBYQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUy1GDuzp3wq+AM6AFU8t61k2c
# 35GgggMtMIIDKTCCAhWgAwIBAgIQE3U7au1O4rZEMExUKPt7LTAJBgUrDgMCHQUA
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
# AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUCLF+nhDG9ERWuMyg
# vQrPXu/8bYAwDQYJKoZIhvcNAQEBBQAEggEAXbyk2yHhFrQgmNReXn9Bja9unARQ
# RChya2aUrZRS5pBWxxQYdLM2+528T7f3tSB6SWB53C6xrhTiKq4pTJ6H9KSMa+9Z
# tOK0+zE/7vbAYdGtLOOgwFommhiG6L4JDM9pgfC4LRG0YT7d9wUhZRxSKnW68uL8
# exo3LBuU/GDuKwDmdbkLpOFHefo7kl1U8gSMs4D6Q7hWEoVSRtxB6jLJp0DgIrYC
# 2Ji+fZL4yYuQC7ssRNboSRnJWEIXeceg6JNVBc96dI1wkK9wgGdqM9rYn9WLgiR4
# Ejn1+Il5LzJJo4SQ1zu9Z7yKezLTgxOr98yPIvxcU32T6o+Iphy08BN49A==
# SIG # End signature block
