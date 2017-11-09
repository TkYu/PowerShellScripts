# Some PowerShell Script

## Firefox Downloader

``Make sure you have PowerShell V3 installed``

```powershell
# 1.Make a new folder and cd to this path
# 2.Hold shift and right click, then click 'Open command window here' or 'Open PowerShell window here'
# 3.Run code

#If PowerShell:
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/TkYu/PowerShellScripts/master/FirefoxDownload/Firefox.ps1'))

#If Command Line:
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/TkYu/PowerShellScripts/master/FirefoxDownload/Firefox.ps1'))"

#If you want some mouse gestures, just change Firefox.ps1 to FirefoxWithFiredoge.ps1
```

