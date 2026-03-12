# 🎥 CCTV Video Converter (Hikvision & Truvision)

A lightweight, automated PowerShell utility designed to seamlessly convert stubborn, proprietary CCTV video exports (like those from Hikvision and Truvision) into universally compatible, standard H.264 MP4 files. 

If your exported CCTV files refuse to play in standard desktop players or fail to process when uploaded to Google Drive, this tool will fix them.

## ✨ Features

* **Universal Playback:** Converts proprietary wrappers and broken headers into clean `H.264/AAC MP4` files guaranteed to work on any player, web browser, or cloud storage (like Google Drive).
* **Hardware Accelerated:** Leverages **Intel QuickSync Video (QSV)** (optimized for Intel 12th-14th Gen CPUs) for lightning-fast encoding. A 1-hour footage file can be converted in just a few minutes.
* **Smart Auto-Scaling:** Automatically detects resolution. If the video is larger than 1080p, it downscales it to 1080p to save massive amounts of space. If it is 1080p or smaller, it retains the original size.
* **Zero-Admin Setup:** Automatically downloads a portable version of `FFmpeg` directly to the user's `AppData` folder. **No Administrator privileges required!**
* **Failsafe Encoding:** Uses the CPU to safely read messy CCTV data, and the QuickSync chip to write the new file. If the PC lacks QuickSync, it automatically falls back to standard CPU encoding.

## 🚀 How to Run (One-Click Setup)

You don't need to download the script manually or install any software. 

1. Open **Windows PowerShell** (Press `Win + R`, type `powershell`, and hit Enter).
2. Paste the following command and hit **Enter**:

```powershell
powershell.exe -ExecutionPolicy Bypass -STA -WindowStyle Normal -Command "irm [https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/CCTV_Converter.ps1](https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/CCTV_Converter.ps1) | iex"
