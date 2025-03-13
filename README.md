# Install-NvidiaApp.ps1

This script automates the detection of an NVIDIA GPU, retrieves the latest NVIDIA App installer (either Enterprise or Public edition), and facilitates its download and installation with customizable parameters.

## Usage

```powershell
.\Install-NvidiaApp.ps1 [options]
```

### Options
- `-Verbose`: Enables verbose logging for detailed output.
- `-DryRun`: Executes the script in a dry run mode to check and extract information without downloading or installing the package.
- `-Force`: Forces the installation of the NVIDIA App even if the same version is already installed or if no NVIDIA GPU is detected.
- `-Edition`: Specifies the edition of the NVIDIA App to install. Valid values are "Enterprise" and "Public". Default is "Public".

### Running the Script from the Internet:
Use `Invoke-RestMethod` to download and execute the script. Here is how you can do it:

```powershell
# Using Invoke-RestMethod
irm https://github.com/emilwojcik93/Install-NvidiaApp/releases/latest/download/Install-NvidiaApp.ps1 | iex
```

> [!NOTE]
> If it doesn't work, then try to [Set-ExecutionPolicy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7.4) via PowerShell (Admin)
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; irm https://github.com/emilwojcik93/Install-NvidiaApp/releases/latest/download/Install-NvidiaApp.ps1 | iex
   ```
> [!NOTE]
> To execute the script from the Internet with additional parameters, please run
   ```powershell
   &([ScriptBlock]::Create((irm https://github.com/emilwojcik93/Install-NvidiaApp/releases/latest/download/Install-NvidiaApp.ps1))) -DryRun
   ```

### Example of execution
```powershell
PS > &([ScriptBlock]::Create((irm https://github.com/emilwojcik93/Install-NvidiaApp/releases/latest/download/Install-NvidiaApp.ps1))) -DryRun
Dry run mode: Skipping download and installation.
GPU Model: NVIDIA GeForce MX450
URL: https://us.download.nvidia.com/nvapp/client/11.0.2.341/NVIDIA_app_v11.0.2.341.exe
Filename: NVIDIA_app_v11.0.2.341.exe
Size of package: 155022288 bytes (147.84 MiB)
Version: 11.0.2.341
Install command: Start-Process -FilePath "C:\Users\6125750\AppData\Local\Temp\NVIDIA_app_v11.0.2.341.exe" -ArgumentList "-s -noreboot -noeula -nofinish -nosplash" -Wait
```