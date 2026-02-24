# Requires PowerShell 5.1+
Add-Type -AssemblyName System.Windows.Forms

# Set up the persistent, user-specific directory (Works for Standard Users and Admins!)
$appDataDir = Join-Path $env:LOCALAPPDATA "CCTVConverter"
$ffmpegPath = Join-Path $appDataDir "ffmpeg.exe"

# Function to pop up a GUI file picker
Function Get-VideoFiles {
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Select CCTV Video Files"
    $OpenFileDialog.Filter = "Video Files|*.mp4;*.avi;*.dav;*.mkv;*.ts|All Files|*.*"
    $OpenFileDialog.Multiselect = $true 
    
    $OpenFileDialog.ShowHelp = $true
    
    if ($OpenFileDialog.ShowDialog() -eq "OK") {
        return $OpenFileDialog.FileNames
    }
    return $null
}

# Function to download and install FFmpeg to AppData
Function Install-FFmpeg {
    Write-Host "Checking FFmpeg installation..." -ForegroundColor Cyan

    if (Test-Path $ffmpegPath) {
        Write-Host "FFmpeg is already installed at: $ffmpegPath" -ForegroundColor Green
        pause
        return
    }

    Write-Host "Downloading latest FFmpeg to your user profile... Please wait." -ForegroundColor Yellow
    
    # Create the directory if it doesn't exist
    if (-not (Test-Path $appDataDir)) {
        New-Item -ItemType Directory -Force -Path $appDataDir | Out-Null
    }

    $zipUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
    $zipPath = Join-Path $appDataDir "ffmpeg_temp.zip"
    $extractPath = Join-Path $appDataDir "ffmpeg_extracted"

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
        Write-Host "Extracting FFmpeg..." -ForegroundColor Cyan
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # Find ffmpeg.exe inside the extracted folder and move it to our AppData folder
        $exePath = Get-ChildItem -Path $extractPath -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1
        Move-Item -Path $exePath.FullName -Destination $ffmpegPath -Force
        
        # Clean up the zip and extracted folders
        Remove-Item -Path $zipPath -Force
        Remove-Item -Path $extractPath -Recurse -Force
        Write-Host "FFmpeg successfully installed permanently for your user account!" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to download FFmpeg. Check your internet connection or firewall." -ForegroundColor Red
        # Clean up partial downloads if it failed
        if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
    }
    pause
}

# Core encoding function
Function Convert-CCTVVideo {
    param([string]$Brand)

    # Auto-check if FFmpeg is installed before trying to convert
    if (-not (Test-Path $ffmpegPath)) {
        Write-Host "FFmpeg not found! Automatically starting the one-time download..." -ForegroundColor Yellow
        Install-FFmpeg
        # If it still doesn't exist after trying to install, abort
        if (-not (Test-Path $ffmpegPath)) { return }
    }

    Write-Host "Opening file picker for $Brand CCTV videos..." -ForegroundColor Cyan
    $files = Get-VideoFiles

    if ($files) {
        foreach ($file in $files) {
            $directory = [System.IO.Path]::GetDirectoryName($file)
            $filename = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $outputFile = Join-Path $directory "$($filename)_Converted.mp4"

            Write-Host "Processing: $filename" -ForegroundColor Yellow
            
            $ffmpegArgs = @(
                "-hwaccel", "qsv", 
                "-i", "`"$file`"", 
                "-c:v", "h264_qsv", 
                "-preset", "medium",
                "-global_quality", "25",
                "-vf", "scale=-2:'min(1080,ih)'",
                "-c:a", "aac", 
                "-b:a", "128k",
                "-y", "`"$outputFile`""
            )

            $process = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgs -Wait -NoNewWindow -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-Host "Success: Saved as $($filename)_Converted.mp4" -ForegroundColor Green
            } else {
                Write-Host "Error converting $filename. (Are you sure Intel QuickSync is active on this PC?)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "No files selected." -ForegroundColor Yellow
    }
    pause
}

# Main Menu Loop
while ($true) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "      CCTV VIDEO CONVERTER (H.264)      " -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "1. Convert Hikvision CCTV"
    Write-Host "2. Convert Truvision CCTV"
    Write-Host "0. Install/Check FFmpeg (Run once)"
    Write-Host "Q. Quit"
    Write-Host "========================================" -ForegroundColor Cyan
    
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        '1' { Convert-CCTVVideo -Brand "Hikvision" }
        '2' { Convert-CCTVVideo -Brand "Truvision" }
        '0' { Install-FFmpeg }
        'Q' { Clear-Host; exit }
        'q' { Clear-Host; exit }
        default { Write-Host "Invalid choice, try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
