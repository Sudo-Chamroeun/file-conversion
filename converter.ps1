# Core encoding function with Automatic QSV-to-CPU Fallback
Function Convert-CCTVVideo {
    param([string]$Brand)

    if (-not (Test-Path $ffmpegPath)) {
        Write-Host "FFmpeg not found! Automatically starting the one-time download..." -ForegroundColor Yellow
        Install-FFmpeg
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
            
            # ATTEMPT 1: CPU Decode -> Intel QuickSync Encode (h264_qsv)
            # Notice we removed "-hwaccel qsv" to let the CPU handle the messy CCTV reading
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

            Write-Host "Attempting Intel QuickSync encoding..." -ForegroundColor Cyan
            $process = Start-Process -FilePath $ffmpegPath -ArgumentList $qsvArgs -Wait -NoNewWindow -PassThru
            
            # Check if QuickSync failed
            if ($process.ExitCode -ne 0) {
                Write-Host "QuickSync failed or is unavailable. Falling back to standard CPU encoding..." -ForegroundColor Yellow
                
                # ATTEMPT 2: Standard CPU Encode (libx264)
                # Slower, but 100% guaranteed to work on any PC.
                $cpuArgs = @(
                    "-i", "`"$file`"", 
                    "-c:v", "libx264", 
                    "-preset", "fast",
                    "-crf", "23",
                    "-vf", "scale=-2:'min(1080,ih)'",
                    "-c:a", "aac", 
                    "-b:a", "128k",
                    "-y", "`"$outputFile`""
                )
                
                $process2 = Start-Process -FilePath $ffmpegPath -ArgumentList $cpuArgs -Wait -NoNewWindow -PassThru
                
                if ($process2.ExitCode -eq 0) {
                    Write-Host "Success: Saved as $($filename)_Converted.mp4 (using CPU)" -ForegroundColor Green
                } else {
                    Write-Host "Critical Error: Could not convert $filename even with CPU fallback. The file might be corrupted." -ForegroundColor Red
                }
            } else {
                Write-Host "Success: Saved as $($filename)_Converted.mp4 (using QuickSync)" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "No files selected." -ForegroundColor Yellow
    }
    pause
}
