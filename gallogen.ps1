param (
  [string]$InputPath = ""
)

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "-> [1/4] Validating infrastructure..." -ForegroundColor Cyan

$DistDir = Join-Path $PSScriptRoot "dist"
$TemplatesDir = Join-Path $PSScriptRoot "templates"

# Check templates
$Templates = @("index.html", "album.html", "photo.html", "styles.css")
foreach ($tpl in $Templates) {
  if (!(Test-Path -LiteralPath (Join-Path $TemplatesDir $tpl))) {
    Write-Error "Error: Missing template $tpl"
    exit 1
  }
}

if ([string]::IsNullOrEmpty($InputPath)) {
  $InputPath = Read-Host "Enter ABSOLUTE path to FastStone folder"
}

$InputPath = $InputPath.Trim('"').Trim("'").Trim()

if (![System.IO.Path]::IsPathRooted($InputPath)) {
  Write-Error "Error: ABSOLUTE path required!"
  exit 1
}

if (!(Test-Path -LiteralPath $InputPath)) {
  Write-Error "Error: Path not found -> $InputPath"
  exit 1
}

$ResolvedSrcPath = (Get-Item -LiteralPath $InputPath).FullName
Write-Host "   Source verified: $ResolvedSrcPath" -ForegroundColor Green

# Wipe old build artifacts and initialize clean environments right after path validation
Write-Host "-> [2/4] Wiping and preparing dist environment..." -ForegroundColor Cyan
if (Test-Path -LiteralPath $DistDir) {
  Remove-Item -LiteralPath $DistDir -Recurse -Force | Out-Null
}
New-Item -ItemType Directory -Path $DistDir | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DistDir "photos") | Out-Null

Copy-Item -LiteralPath (Join-Path $TemplatesDir "styles.css") -Destination (Join-Path $DistDir "styles.css") -Force
New-Item -Path $DistDir -Name ".nojekyll" -ItemType "file" -Force | Out-Null

Write-Host "-> [3/4] Loading layout templates..." -ForegroundColor Cyan
$IndexTemplate = Get-Content -LiteralPath (Join-Path $TemplatesDir "index.html") -Raw -Encoding UTF8
$AlbumTemplate = Get-Content -LiteralPath (Join-Path $TemplatesDir "album.html") -Raw -Encoding UTF8
$PhotoTemplate = Get-Content -LiteralPath (Join-Path $TemplatesDir "photo.html") -Raw -Encoding UTF8

Write-Host "-> [4/4] Compiling static gallery asset tree..." -ForegroundColor Cyan
$folders = Get-ChildItem -LiteralPath $ResolvedSrcPath -Recurse | Where-Object { $_.PSIsContainer }
$folders = @(Get-Item -LiteralPath $ResolvedSrcPath) + $folders

# Count files first for accurate global progress calculation
$totalFiles = (Get-ChildItem -LiteralPath $ResolvedSrcPath -Recurse -File | Where-Object { $_.Extension -match '\.(jpg|jpeg|png)$' }).Count
$processedFilesCount = 0

$albumList = @()
$rootPhotosGrid = ""

# Inline slugify helper function with Cyrillic translit support (AFG-01)
function Get-WebSlug ($name) {
  # Properly extract group from the Hashtable if regex matches
  if ($name -match '^([^(]+)\(([^)]+)\)') {
    $name = $Matches[1].Trim()
  }

  # Dictionary for Cyrillic to Latin transliteration
  $cyr = @('а','б','в','г','д','е','ё','ж','з','и','й','к','л','м','н','о','п','р','с','т','у','ф','х','ц','ч','ш','щ','ъ','ы','ь','э','ю','я')
  $lat = @('a','b','v','g','d','e','yo','zh','z','i','y','k','l','m','n','o','p','r','s','t','u','f','kh','ts','ch','sh','shch','','y','','e','yu','ya')

  $name = $name.ToLower()
  for ($i = 0; $i -lt $cyr.Length; $i++) {
    $name = $name.Replace($cyr[$i], $lat[$i])
  }

  $slug = $name.Replace(" ", "-").Replace("_", "-")
  $slug = [regex]::Replace($slug, "[^a-z0-9-]", "")
  $slug = [regex]::Replace($slug, "-+", "-")
  return $slug.Trim("-")
}

foreach ($folder in $folders) {
  $fsSortPath = Join-Path $folder.FullName "fssort.ini"
  $filesInFolder = Get-ChildItem -LiteralPath $folder.FullName -File | Where-Object { $_.Extension -match '\.(jpg|jpeg|png)$' }

  if ($filesInFolder.Count -eq 0) { continue }

  # Process folder name and check for manual translation override file (AFG-01)
  $rawFolderName = $folder.Name
  $infoFile = Join-Path $folder.FullName "album_info.txt"

  if ($folder.FullName -eq $ResolvedSrcPath) {
    $albumDisplayName = "Main Album"
    $albumSlug = "index"
  } else {
    if (Test-Path -LiteralPath $infoFile) {
      # Parse key-value structure using native ConvertFrom-StringData
      $infoContent = Get-Content -LiteralPath $infoFile -Raw -Encoding UTF8
      $infoData = ConvertFrom-StringData -StringData $infoContent
      if ($infoData.ContainsKey("AlbumName")) {
        # Strip outer quotes from the string value if present
        $albumDisplayName = $infoData.AlbumName.Trim('"').Trim("'").Trim()
      } else {
        $albumDisplayName = $rawFolderName
      }
    } elseif ($rawFolderName -match '^([^(]+)\(([^)]+)\)') {
      $albumDisplayName = "$($Matches.Trim()) / $($Matches.Trim())"
    } else {
      $albumDisplayName = $rawFolderName
    }

    # Process full relative path into slugified web path
    $relFolderRawPath = $folder.FullName.Replace($ResolvedSrcPath, "").TrimStart("\")
    $slugParts = @()
    foreach ($part in $relFolderRawPath.Split("\")) {
      if (![string]::IsNullOrWhiteSpace($part)) {
        $subInfoFile = Join-Path $folder.Parent.FullName $part "album_info.txt"
        if (Test-Path -LiteralPath $subInfoFile) {
          $subContent = Get-Content -LiteralPath $subInfoFile -Raw -Encoding UTF8
          $subData = ConvertFrom-StringData -StringData $subContent
          if ($subData.ContainsKey("AlbumName")) {
            $slugParts += Get-WebSlug $subData.AlbumName.Trim('"').Trim("'")
          } else {
            $slugParts += Get-WebSlug $part
          }
        } else {
          $slugParts += Get-WebSlug $part
        }
      }
    }
    $albumSlug = $slugParts -join "-"
  }

  Write-Host "   Processing album: $albumDisplayName -> ($albumSlug.html)" -ForegroundColor Yellow

  # FastStone sort order
  if (Test-Path -LiteralPath $fsSortPath) {
    $sortOrder = Get-Content -LiteralPath $fsSortPath -Encoding UTF8 | Where-Object { ![string]::IsNullOrWhiteSpace($_) }
    $sortedFiles = foreach ($name in $sortOrder) {
      $matchedFile = $filesInFolder | Where-Object { $_.Name -eq $name }
      if ($matchedFile) { $matchedFile }
    }
    $leftovers = $filesInFolder | Where-Object { $sortOrder -notcontains $_.Name }
    $sortedFiles = @($sortedFiles) + @($leftovers)
  } else {
    $sortedFiles = $filesInFolder | Sort-Object Name
  }

  $photosGridHtml = ""

  foreach ($file in $sortedFiles) {
    if ($null -eq $file) { continue }

    $processedFilesCount++
    $percentComplete = [math]::Round(($processedFilesCount / $totalFiles) * 100)

    # Generic progress bar message
    Write-Progress -Activity "Compiling requested Gallery..." -Status "Processing: $($file.Name)" -PercentComplete $percentComplete

    # Calculate web-safe destination paths
    if ($albumSlug -eq "index") {
      $webRelPath = $file.Name
      $targetFileAbsolutePath = Join-Path $DistDir "photos/$webRelPath"
    } else {
      $webRelPath = $albumSlug + "/" + $file.Name
      $targetFileAbsolutePath = Join-Path $DistDir "photos/$webRelPath"
    }

    $targetFileFolder = Split-Path $targetFileAbsolutePath -Parent
    if (!(Test-Path -LiteralPath $targetFileFolder)) { New-Item -ItemType Directory -Path $targetFileFolder | Out-Null }

    # Copy original file into newly generated clean web structure
    Copy-Item -LiteralPath $file.FullName -Destination $targetFileAbsolutePath -Force

    # EXIF Data
    $dateTaken = "N/A"
    $cameraModel = "Unknown"
    try {
      $fs = New-Object System.IO.FileStream($file.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
      $img = [System.Drawing.Image]::FromStream($fs)
      if ($img.PropertyIdList -contains 36867) { $dateTaken = [System.Text.Encoding]::ASCII.GetString($img.GetPropertyItem(36867).Value).Trim().Replace("`0", "") }
      if ($img.PropertyIdList -contains 272) { $cameraModel = [System.Text.Encoding]::ASCII.GetString($img.GetPropertyItem(272).Value).Trim().Replace("`0", "") }
      $img.Dispose(); $fs.Dispose()
    } catch { if ($img) { $img.Dispose() }; if ($fs) { $fs.Dispose() } }

    # Generate unique HTML ID based on safe web relative path
    $photoId = "id-" + $webRelPath.Replace("/", "-").Replace(".", "-").Replace(" ", "-")

    # Strict Fluent API with trailing dots - fully compatible with modern .ps1 script engine
    $photosGridHtml += $PhotoTemplate.
      Replace("{{REL_PATH}}", $webRelPath).
      Replace("{{FILE_NAME}}", $file.Name).
      Replace("{{CAMERA}}", $cameraModel).
      Replace("{{DATE}}", $dateTaken).
      Replace("{{PHOTO_ID}}", $photoId) + "`n"
  }

  if ($albumSlug -ne "index") {
    $albumContent = $AlbumTemplate.Replace("{{ALBUM_NAME}}", $albumDisplayName).Replace("{{PHOTOS_GRID}}", $photosGridHtml)
    $albumContent | Out-File -LiteralPath (Join-Path $DistDir "$albumSlug.html") -Encoding utf8NoBOM
    $albumList += @{ name = $albumDisplayName; slug = "$albumSlug.html" }
  } else {
    $rootPhotosGrid = $photosGridHtml
  }
}

# Clear progress bar when done
Write-Progress -Activity "Compiling requested Gallery..." -Completed

# Generate Index
$albumsLinksHtml = ""
foreach ($album in $albumList) {
  $albumsLinksHtml += "        <a href='$($album.slug)' class='album-card'><h3>$($album.name)</h3></a>`n"
}

$rootPhotosSectionHtml = ""
if (![string]::IsNullOrEmpty($rootPhotosGrid)) {
  $rootPhotosSectionHtml = "<h2>Root Photos</h2><div class='grid'>$rootPhotosGrid</div>"
}

$FinalIndexContent = $IndexTemplate.
  Replace("{{TITLE}}", "Sukhoi Su-34 Detailed Walkaround").
  Replace("{{ALBUMS_LINKS}}", $albumsLinksHtml).
  Replace("{{ROOT_PHOTOS_SECTION}}", $rootPhotosSectionHtml)

$FinalIndexContent | Out-File -LiteralPath (Join-Path $DistDir "index.html") -Encoding utf8NoBOM

Write-Host "[+] Build complete successfully. Total files processed: $totalFiles. Check ./dist" -ForegroundColor Green
