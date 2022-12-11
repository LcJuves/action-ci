$platform = [System.Environment]::OSVersion.Platform
if (!$platform.ToString().StartsWith('Win')) {
    Write-Host "Support Windows only!"
    exit -1
}

$installGitBashArgs = ('-Command', 'irm https://liangchengj.github.io/action-ci/scripts/pwsh/Install-Git-Bash.ps1 | iex')
$installGitBashProc = Start-Process -FilePath powershell.exe -ArgumentList $installGitBashArgs -Verb RunAs -Wait -PassThru
$installGitBashProcExitCode = $installGitBashProc.ExitCode
if (!$installGitBashProcExitCode -eq 0) {
    exit $installGitBashProcExitCode
}

function Get-Git-Install-Path-Property {
    try {
        return Get-ItemProperty HKLM:\SOFTWARE\GitForWindows InstallPath
    }
    catch {
        return Get-ItemProperty HKCU:\SOFTWARE\GitForWindows InstallPath
    }
}

$installPath = (Get-Git-Install-Path-Property).InstallPath.ToString()
$gitBashProcess = Start-Process -FilePath "$installPath\git-bash.exe" -WorkingDirectory $installPath -Verb RunAs -PassThru
$gitBashExitCode = $gitBashProcess.ExitCode
if (!$gitBashExitCode -eq 0) {
    exit $gitBashExitCode
}

Add-Type -MemberDefinition @"
[DllImport("user32.dll", SetLastError = true)]
private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

[DllImport("user32.dll", SetLastError = true)]
private static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);

[DllImport("user32.dll")]
private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

public static int FindAndFocusWindow(string windowName) {
    int retryCount = 1;
    int hWnd = (int)FindWindow(null, windowName);
    while (true) {
        if (hWnd != 0 || retryCount == 60) break;
        retryCount++;
        System.Threading.Thread.Sleep(500);
        hWnd = (int)FindWindow(null, windowName);
    }
    SwitchToThisWindow(new IntPtr(hWnd), true);
    return hWnd;
}

public static void SendKeys(byte[] vks) {
    foreach (var vk in vks) {
        keybd_event(vk, 0, 0, 0);
        keybd_event(vk, 0, 2, 0);
    }
}

public static void ShiftIns() {
    const byte VK_SHIFT = 0x10;
    const byte VK_INSERT = 0x2D;
    keybd_event(VK_SHIFT, 0, 0, 0);
    SendKeys(new byte[] { VK_INSERT });
    keybd_event(VK_SHIFT, 0, 2, 0);
}

public static void Enter() {
    const byte VK_ENTER = 0x0D;
    SendKeys(new byte[] { VK_ENTER });
}
"@ -Name FunctionsV14 -Namespace Win32API -PassThru

function Switch-To-Git-Bash-Window {
    $bitInfo = if ([System.Environment]::Is64BitOperatingSystem) { "64" } else { "32" }
    $hWnd = [Win32API.FunctionsV14]::FindAndFocusWindow("MINGW${bitInfo}:/")
    if ($hWnd -eq 0) {
        Write-Host "Can't find `Git Bash` window"
        return -1
    }
}

function Send-Command-To-Git-Bash-Window {
    param (
        [string] $CommandLine
    )

    Set-Clipboard -Value "$CommandLine"
    Switch-To-Git-Bash-Window
    [Win32API.FunctionsV14]::ShiftIns()
    Switch-To-Git-Bash-Window
    [Win32API.FunctionsV14]::Enter()
    Set-Clipboard -Value " "
}

Start-Sleep -Seconds 3
Send-Command-To-Git-Bash-Window @"
(curl -fsSL https://github.liangchengj.com/clang/linux-like/git_bash_install_pacman.sh | sh) && sleep 3 && exit
"@
