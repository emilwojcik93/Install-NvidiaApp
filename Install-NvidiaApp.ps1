<#
.SYNOPSIS
    This script automates the detection of an NVIDIA GPU, retrieves the latest NVIDIA App installer (either Enterprise or Public edition), and facilitates its download and installation with customizable parameters.
.DESCRIPTION
    This script efficiently manages the process of downloading and installing the latest NVIDIA App by:
    - Scraping the NVIDIA App webpage to locate the most recent installer.
    - Verifying the existence and size of the installer file locally.
    - Confirming the presence of an NVIDIA GPU on the machine prior to installation.
    - Supporting a dry run mode to simulate operations without actual downloading or installation.
    - Allowing the user to choose between the Enterprise and Public editions of the NVIDIA App.
.PARAMETER Verbose
    Enables verbose logging for detailed output.
.PARAMETER DryRun
    Executes the script in a dry run mode to check and extract information without downloading or installing the package.
.PARAMETER Force
    Forces the installation of the NVIDIA App even if the same version is already installed or if no NVIDIA GPU is detected.
.PARAMETER Edition
    Specifies the edition of the NVIDIA App to install. Valid values are "Enterprise" and "Public". Default is "Public".
.EXAMPLE
    .\Install-NvidiaApp.ps1 -Verbose
.EXAMPLE
    .\Install-NvidiaApp.ps1 -Force
.EXAMPLE
    .\Install-NvidiaApp.ps1 -DryRun
.EXAMPLE
    .\Install-NvidiaApp.ps1 -Edition Enterprise
.LINK
    NVIDIA App Enterprise: https://www.nvidia.com/en-us/software/nvidia-app-enterprise/
    NVIDIA App Public: https://www.nvidia.com/en-us/software/nvidia-app/
#>

param (
    [switch]$Verbose,
    [switch]$DryRun,
    [switch]$Force,
    [string]$Edition = "Public"
)

function Get-NvidiaDownloadLink {
    param (
        [string]$url
    )
    Write-Verbose "Scraping URL: $url"
    $response = Invoke-WebRequest -Uri $url
    $downloadLink = $null

    if ($response.Content -match 'https:\/\/us\.download\.nvidia\.com\/nvapp\/client\/[\d\.]+\/NVIDIA_app_v[\d\.]+\.exe') {
        $downloadLink = $matches[0]
    }
    elseif ($response.Content -match '<a[^>]*href="([^"]*nv[^"]*app[^"]*\.exe)"[^>]*>\s*<span[^>]*>Download Now<\/span>') {
        $downloadLink = $matches[1]
    }
    elseif ($response.Content -match 'href="([^"]*nv[^"]*app[^"]*\.exe)"') {
        $downloadLink = $matches[1]
    }

    return $downloadLink
}

function Get-RemoteFileSize {
    param (
        [string]$url
    )
    Write-Verbose "Getting remote file size for URL: $url"
    $response = Invoke-WebRequest -Uri $url -Method Head
    $remoteFileSize = $response.Headers['Content-Length']
    if ($remoteFileSize) {
        if ($remoteFileSize -is [array]) {
            $remoteFileSize = $remoteFileSize[0]
        }
        return [int64]$remoteFileSize
    } else {
        Write-Warning "Could not determine the remote file size."
        return 0
    }
}

function Save-File {
    param (
        [string]$url,
        [string]$path
    )
    Write-Verbose "Downloading file from URL: $url to path: $path"
    Invoke-WebRequest -Uri $url -OutFile $path
}

function Install-Application {
    param (
        [string]$installerPath,
        [string]$installParams
    )
    Write-Verbose "Installing NVIDIA App from path: $installerPath with parameters: $installParams"
    Start-Process -FilePath $installerPath -ArgumentList $installParams -Wait
}

function Test-NvidiaGPU {
    Write-Verbose "Checking for NVIDIA GPU presence"
    $gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" -or $_.VideoProcessor -like "*NVIDIA*" }

    if ($gpu) {
        if ($gpu.Name) {
            Write-Verbose "NVIDIA GPU recognized: Name = $($gpu.Name)"
            return $gpu.Name
        }
        elseif ($gpu.VideoProcessor) {
            Write-Verbose "NVIDIA GPU recognized: VideoProcessor = $($gpu.VideoProcessor)"
            return $gpu.VideoProcessor
        }
    }
    else {
        return $null
    }
}

function Get-InstalledNvidiaAppVersion {
    $appPath = Join-Path -Path ${env:ProgramFiles} -ChildPath "NVIDIA Corporation\NVIDIA app\CEF\NVIDIA app.exe"
    if (Test-Path $appPath) {
        $fileVersionInfo = Get-Item $appPath | Select-Object -ExpandProperty VersionInfo
        return $fileVersionInfo.ProductVersion
    }
    else {
        return $null
    }
}

function Install-NvidiaApp {
    param (
        [switch]$Verbose,
        [switch]$DryRun,
        [switch]$Force,
        [string]$Edition = "Public"
    )

    Write-Verbose "Script parameters:"
    Write-Verbose "Verbose: $Verbose"
    Write-Verbose "DryRun: $DryRun"
    Write-Verbose "Force: $Force"
    Write-Verbose "Edition: $Edition"

    $gpuModel = Test-NvidiaGPU
    if (-not $gpuModel) {
        if ($Force) {
            $gpuModel = "unknown"
            Write-Warning "No NVIDIA GPU found but `"`$Force`" parameter is declared, setting `$gpuModel = `"$gpuModel`".`nThe NVIDIA installer might do nothing because installer also will make automatic check for Nvidia GPU."
        } else {
            Write-Error "No NVIDIA GPU found. Exiting."
            throw "No NVIDIA GPU found."
        }
    }

    $url = if ($Edition -eq "Enterprise") {
        "https://www.nvidia.com/en-us/software/nvidia-app-enterprise/"
    } else {
        "https://www.nvidia.com/en-us/software/nvidia-app/"
    }

    $downloadLink = Get-NvidiaDownloadLink -url $url
    $installParams = "-s -noreboot -noeula -nofinish -nosplash"

    if ($downloadLink) {
        Write-Verbose "Download link found: $downloadLink"
        $fileName = [System.IO.Path]::GetFileName($downloadLink)
        if ($downloadLink -match '_v(\d+\.\d+\.\d+\.\d+)\.exe') {
            $version = $matches[1]
        }
        else {
            $version = "Unknown"
        }
        Write-Verbose "Extracted version: $version"
        $installerPath = Join-Path -Path $env:Temp -ChildPath $fileName
        $remoteFileSize = Get-RemoteFileSize -url $downloadLink
        $remoteFileSizeMiB = [math]::Round($remoteFileSize / 1MB, 2)
        Write-Verbose "Remote file size: $remoteFileSize bytes ($remoteFileSizeMiB MiB)"

        $installedVersion = Get-InstalledNvidiaAppVersion

        $output = [PSCustomObject]@{
            GPUModel       = $gpuModel
            URL            = $downloadLink
            Filename       = $fileName
            SizeOfPackage  = "$remoteFileSize bytes ($remoteFileSizeMiB MiB)"
            Version        = $version
            InstallCommand = "Start-Process -FilePath `"$installerPath`" -ArgumentList `"$installParams`" -Wait"
        }

        if ($DryRun) {
            Write-Output "Dry run mode: Skipping download and installation."
            return $output
        }

        if ($installedVersion -and $installedVersion -eq $version -and -not $Force) {
            Write-Output "NVIDIA App version: ${installedVersion} is already installed. Skipping installation."
            return
        }

        if (-not $DryRun) {
            if (Test-Path $installerPath) {
                $localFileSize = (Get-Item $installerPath).Length
                if ($localFileSize -eq $remoteFileSize) {
                    Write-Verbose "File already exists and has the same size. Skipping download."
                }
                else {
                    Write-Verbose "File exists but sizes do not match. Downloading again."
                    Save-File -url $downloadLink -path $installerPath
                }
            }
            else {
                Save-File -url $downloadLink -path $installerPath
            }

            Install-Application -installerPath $installerPath -installParams $installParams

            $installedVersion = Get-InstalledNvidiaAppVersion
            if ($installedVersion) {
                Write-Output "NVIDIA App version: ${installedVersion} was installed successfully."
            } else {
                Write-Warning "NVIDIA App does not exist after installation."
            }
        }
    }
    else {
        Write-Warning "Download link not found. The NVIDIA installer might do nothing."
    }
}

# Enable verbose logging if the -Verbose switch is provided
if ($Verbose) {
    $VerbosePreference = "Continue"
}

Install-NvidiaApp -Verbose:$Verbose -DryRun:$DryRun -Force:$Force -Edition $Edition