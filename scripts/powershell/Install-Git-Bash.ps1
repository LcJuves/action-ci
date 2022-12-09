function Start-DownloadWithRetry {
    Param
    (
        [Parameter(Mandatory)]
        [string] $Url,
        [string] $Name,
        [string] $DownloadPath = "${env:Temp}",
        [int] $Retries = 20
    )

    if ([String]::IsNullOrEmpty($Name)) {
        $Name = [IO.Path]::GetFileName($Url)
    }

    $filePath = Join-Path -Path $DownloadPath -ChildPath $Name
    $downloadStartTime = Get-Date

    # Default retry logic for the package.
    while ($Retries -gt 0) {
        try {
            $downloadAttemptStartTime = Get-Date
            Write-Host "Downloading package from: $Url to path $filePath ."
            (New-Object System.Net.WebClient).DownloadFile($Url, $filePath)
            break
        }
        catch {
            $failTime = [math]::Round(($(Get-Date) - $downloadStartTime).TotalSeconds, 2)
            $attemptTime = [math]::Round(($(Get-Date) - $downloadAttemptStartTime).TotalSeconds, 2)
            Write-Host "There is an error encounterd after $attemptTime seconds during package downloading:`n $_"
            $Retries--

            if ($Retries -eq 0) {
                Write-Host "File can't be downloaded. Please try later or check that file exists by url: $Url"
                Write-Host "Total time elapsed $failTime"
                exit 1
            }

            Write-Host "Waiting 30 seconds before retrying. Retries left: $Retries"
            Start-Sleep -Seconds 30
        }
    }

    $downloadCompleteTime = [math]::Round(($(Get-Date) - $downloadStartTime).TotalSeconds, 2)
    Write-Host "Package downloaded successfully in $downloadCompleteTime seconds"
    return $filePath
}


$headers = @{}
$headers.Add("accept", "application/json")
$response = Invoke-WebRequest -Uri 'https://api.github.com/repos/git-for-windows/git/releases' -Method GET -Headers $headers
$responseJson = ConvertFrom-Json -InputObject $response
foreach ($release in $responseJson) {
    if (!$release.prerelease) {

        foreach ($asset in $release.assets) {
            $name = $asset.name
            $doNext = $false
            if ([System.Environment]::Is64BitOperatingSystem) {
                $doNext = $name.EndsWith('64-bit.exe')
            }
            elseif ($name.EndsWith('32-bit.exe')) {
                $doNext = $true
            }

            if ($doNext) {
                $downloadUrl = $asset.browser_download_url
                $filePath = Start-DownloadWithRetry -Url $downloadUrl -Name $name

                Write-Host "Starting Install ..."
                $bootstrapperArgumentList = ('/SILENT', '/NORESTART', '/DIR="C:\Git"')
                $process = Start-Process -FilePath $filePath -ArgumentList $bootstrapperArgumentList -Wait -PassThru

                $exitCode = $process.ExitCode
                if ($exitCode -eq 0) {
                    Write-Host "Installation successful"
                }
                else {
                    Write-Host "Non zero exit code returned by the installation process : $exitCode"
                }
                exit $exitCode
            }
        }
    }
}
