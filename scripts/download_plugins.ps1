Param()

# Downloads latest APK assets for Termux plugin repos into release-apks\
# Repos: termux-api, termux-boot, termux-float, termux-styling

$repos = @(
    "termux/termux-api",
    "termux/termux-boot",
    "termux/termux-float",
    "termux/termux-styling"
)

$dest = Join-Path $PSScriptRoot "..\release-apks"
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

foreach ($repo in $repos) {
    Write-Host "Fetching latest release for $repo ..."
    try {
        $api = "https://api.github.com/repos/$repo/releases/latest"
        $rel = Invoke-RestMethod -Uri $api -UseBasicParsing -Headers @{ 'User-Agent' = 'termux-release-prep-script' }
        if ($null -eq $rel.assets) { Write-Host "No assets found for $repo"; continue }
        $apkAsset = $rel.assets | Where-Object { $_.name -like "*.apk" } | Select-Object -First 1
        if ($null -eq $apkAsset) { Write-Host "No APK asset found for $repo"; continue }
        $url = $apkAsset.browser_download_url
        $outFile = Join-Path $dest $apkAsset.name
        Write-Host "Downloading $($apkAsset.name) to $outFile"
        Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing -Headers @{ 'User-Agent' = 'termux-release-prep-script' }
    } catch {
        Write-Host "Failed to fetch release for $repo: $_"
    }
}

Write-Host "Done. Plugin APKs (if any) are in: $dest"