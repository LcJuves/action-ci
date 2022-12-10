$platform = [System.Environment]::OSVersion.Platform
if (!$platform.ToString().StartsWith('Win')) {
    Write-Host "Support Windows only!"
    exit -1
}

$bootstrapperArgumentList = ('-Command', 'irm https://liangchengj.github.io/action-ci/scripts/pwsh/Install-Git-Bash.ps1 | iex')
$process = Start-Process -FilePath powershell.exe -ArgumentList $bootstrapperArgumentList -Wait -PassThru
$exitCode = $process.ExitCode
if (!$exitCode -eq 0) {
    exit $exitCode
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
$gitBashProcess = Start-Process -FilePath "$installPath\git-bash.exe" -Verb RunAs -PassThru
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
        if (hWnd != 0 || retryCount == 20) break;
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

public static void CtrlV() {
    const byte VK_CTRL = 0xA2;
    keybd_event(VK_CTRL, 0, 0, 0);
    SendKeys(new byte[] { 0x56 });
    keybd_event(VK_CTRL, 0, 2, 0);
}

public static void Enter() {
    const byte VK_ENTER = 0x0D;
    SendKeys(new byte[] { VK_ENTER });
}
"@ -Name FunctionsV10 -Namespace Win32API -PassThru
$hWnd = [Win32API.FunctionsV10]::FindAndFocusWindow("MINGW64:/c/Users/admin_15569366340196/Desktop/WorkSpace/MyApp")
Write-Host "Git Bash's HWND >>> $hWnd"
Start-Sleep -Seconds 3

Set-Clipboard -Value "curl -fsSL https://github.liangchengj.com/clang/linux-like/git_bash_install_pacman.sh | sh"
[Win32API.FunctionsV10]::CtrlV()
Start-Sleep -Seconds 1
[Win32API.FunctionsV10]::Enter()
Set-Clipboard -Value " "
