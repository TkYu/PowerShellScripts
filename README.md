# Some PowerShell Script
## Chrome Downloader/Chrome一键下载

**Make sure you have PowerShell V3 installed/请务必确认系统的PowerShell版本大于V3**

**可以在PowerShell中运行``$PSVersionTable.PSVersion.Major``以获取当前的PowerShell版本**

```powershell
# 1.Make a new folder and cd to this path/新建一个文件夹，然后进入该目录
# 2.Hold shift and right click, then click 'Open command window here' or 'Open PowerShell window here'/按住Shift单击滑鼠右键，点击'在此处打开PowerShell窗口'或者'在此处打开命令行窗口'
# 3.Run code/运行以下脚本

#If PowerShell:/如果你运行的是PowerShell：
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/TkYu/PowerShellScripts/master/ChromeDownload/Chrome.ps1'))

#If Command Line:/如果你运行的是Windows命令行：
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/TkYu/PowerShellScripts/master/ChromeDownload/Chrome.ps1'))"

```

>If you want some mouse gestures, just change Chrome.ps1 to ChromeWithGreenChrome.ps1
>如果你需要一些鼠标手势及高级功能，将脚本中的Chrome.ps1替换为ChromeWithGreenChrome.ps1以尝试[GreenChrome](https://github.com/shuax/GreenChrome)

### Enviroments/环境变量

- $env:ggdir='D:\chrome' #Set install location/指定安装的目录，不指定将会默认当前文件夹，如果不存在将会尝试创建
- $env:ggarch='x86' #Set install arch, x64 as x64，x86 as x86/指定下载的架构版本，默认和系统一致，x64代表64位，x86代表32位
- $env:ggbranch='beta' #Set install branch, you can choose beta/dev/canary or leave null for stable/指定下载的分支，默认是正式版，也可以选填beta、dev、canary

## Firefox Downloader/Firefox一键下载

**Make sure you have PowerShell V3 installed/请务必确认系统的PowerShell版本大于V3/**

**可以在PowerShell中运行``$PSVersionTable.PSVersion.Major``以获取当前的PowerShell版本**

```powershell
# 1.Make a new folder and cd to this path/新建一个文件夹，然后进入该目录
# 2.Hold shift and right click, then click 'Open command window here' or 'Open PowerShell window here'/按住Shift单击滑鼠右键，点击'在此处打开PowerShell窗口'或者'在此处打开命令行窗口'
# 3.Run code/运行以下脚本

#If PowerShell:/如果你运行的是PowerShell：
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/TkYu/PowerShellScripts/master/FirefoxDownload/Firefox.ps1'))

#If Command Line:/如果你运行的是Windows命令行：
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/TkYu/PowerShellScripts/master/FirefoxDownload/Firefox.ps1'))"


```

>If you want some mouse gestures, just change Firefox.ps1 to FirefoxWithFiredoge.ps1
>如果你需要一些鼠标手势及高级功能，将脚本中的Firefox.ps1替换为FirefoxWithFiredoge.ps1以尝试[Firedoge](https://shuax.com/portfolio/firedoge/)

### Enviroments/环境变量

- $env:ffdir='D:\firefox' #Set install location/指定安装的目录，不指定将会默认当前文件夹，如果不存在将会尝试创建
- $env:ffloc='zh-CN' #Set install language/指定安装语言，如果不指定默认为当前系统语言
- $env:ffarch='win64' #Set install arch, win64 for x64，win for x86 or leave null for same with system/指定下载的架构版本，默认和系统一致，win64代表64位，win代表32位
- $env:ffbranch='beta' #Set install branch, you can choose beta/dev/nightly/esr or leave null for stable/指定下载的分支，默认是正常版，可以填beta、dev、nightly或者esr



# PS

You can run two commands in one line in Windows CMD/Windows CMD中可以通过&&来并列运行语句

for example, I want install beta version chrome at D:\chrome:/举个例子，假如我想安装beta版本的chrome到D:\chrome下：

> SET "ggbranch=beta" && SET "ggdir=D:\chrome" && @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('<https://raw.githubusercontent.com/TkYu/PowerShellScripts/master/ChromeDownload/Chrome.ps1>'))"

[look this](https://stackoverflow.com/questions/8055371/how-do-i-run-two-commands-in-one-line-in-windows-cmd)

