# Requires PowerShell 5.1+
# Ensure the console is running in STA mode (required for GUI popups)
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Write-Warning "PowerShell is not running in STA mode. The GUI might not load correctly."
}

Add-Type -AssemblyName System.Windows.Forms

# Set up the persistent AppData directory
$appDataDir = Join-Path $env:LOCALAPPDATA "CCTVConverter"
$ffmpegPath = Join-Path $appDataDir "ffmpeg.exe"

# Function to pop up a GUI file picker FORCED to the front
Function Get-VideoFiles {
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Select CCTV Video Files"
    $OpenFileDialog.Filter = "Video Files|*.mp4;*.avi;*.dav;*.mkv;*.ts|All Files|*.*"
    $OpenFileDialog.Multiselect = $true 
    
    # Trick to force the dialog to the front
    $dummyForm = New-Object System.Windows.Forms.Form
    $dummyForm.TopMost = $true
    
    if ($OpenFileDialog.ShowDialog($dummyForm) -eq "OK") {
        return $OpenFileDialog.FileNames
    }
    return $null
}

# Function to download and install FFmpeg to AppData
Function Install-FFmpeg {
    Write-Host "Checking FFmpeg..." -ForegroundColor Cyan

    if (Test-Path $ffmpegPath) {
        Write-Host "FFmpeg is ready to go!" -ForegroundColor Green
        Start-Sleep -Seconds 1
        return
    }

    Write-Host "First-time setup: Downloading FFmpeg... Please wait." -ForegroundColor Yellow
    
    if (-not (Test-Path $appDataDir)) {
        New-Item -ItemType Directory -Force -Path $appDataDir | Out-Null
    }

    $zipUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
    $zipPath = Join-Path $appDataDir "ffmpeg_temp.zip"
    $extractPath = Join-Path $appDataDir "ffmpeg_extracted"

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
        Write-Host "Extracting..." -ForegroundColor Cyan
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        $exePath = Get-ChildItem -Path $extractPath -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1
        Move-Item -Path $exePath.FullName -Destination $ffmpegPath -Force
        
        Remove-Item -Path $zipPath -Force
        Remove-Item -Path $extractPath -Recurse -Force
        Write-Host "Setup complete!" -ForegroundColor Green
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "Failed to download FFmpeg. Check firewall or internet." -ForegroundColor Red
        if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
        pause
    }
}

# Core encoding function
Function Convert-CCTVVideo {
    param([string]$Brand)

    Install-FFmpeg
    if (-not (Test-Path $ffmpegPath)) { return }

    Write-Host "Opening file picker for $Brand videos (Look for the popup window!)..." -ForegroundColor Cyan
    $files = Get-VideoFiles

    if ($files) {
        foreach ($file in $files) {
            $directory = [System.IO.Path]::GetDirectoryName($file)
            $filename = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $outputFile = Join-Path $directory "$($filename)_Converted.mp4"

            Write-Host "`nProcessing: $filename" -ForegroundColor Yellow
            
            # Using CPU to read (safest for CCTV) and QuickSync to write (fastest for 13th/14th Gen)
            $qsvArgs = @(
                "-i", "`"$file`"", 
                "-c:v", "h264_qsv", 
                "-preset", "medium",
                "-global_quality", "25",
                "-vf", "scale=-2:'min(1080,ih)'",
                "-c:a", "aac", 
                "-b:a", "128k",
                "-y", "`"$outputFile`""
            )

            $process = Start-Process -FilePath $ffmpegPath -ArgumentList $qsvArgs -Wait -NoNewWindow -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-Host "Success: Saved as $($filename)_Converted.mp4 (QuickSync)" -ForegroundColor Green
            } else {
                Write-Host "QuickSync failed on this file. Attempting CPU fallback..." -ForegroundColor Yellow
                
                $cpuArgs = @(
                    "-i", "`"$file`"", "-c:v", "libx264", "-preset", "fast", "-crf", "23",
                    "-vf", "scale=-2:'min(1080,ih)'", "-c:a", "aac", "-b:a", "128k", "-y", "`"$outputFile`""
                )
                $process2 = Start-Process -FilePath $ffmpegPath -ArgumentList $cpuArgs -Wait -NoNewWindow -PassThru
                
                if ($process2.ExitCode -eq 0) {
                    Write-Host "Success: Saved as $($filename)_Converted.mp4 (CPU)" -ForegroundColor Green
                } else {
                    Write-Host "Error: File may be too corrupted to convert." -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "No files selected." -ForegroundColor Yellow
    }
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main Menu
while ($true) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "      CCTV VIDEO CONVERTER (1080p)      " -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "1. Convert Hikvision CCTV"
    Write-Host "2. Convert Truvision CCTV"
    Write-Host "0. Force reinstall FFmpeg"
    Write-Host "Q. Quit"
    Write-Host "========================================" -ForegroundColor Cyan
    
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        '1' { Convert-CCTVVideo -Brand "Hikvision" }
        '2' { Convert-CCTVVideo -Brand "Truvision" }
        '0' { Remove-Item $ffmpegPath -Force -ErrorAction SilentlyContinue; Install-FFmpeg }
        'Q' { Clear-Host; exit }
        'q' { Clear-Host; exit }
        default { Write-Host "Invalid choice." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
