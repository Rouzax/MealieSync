function Test-UpdateAvailable {
    <#
    .SYNOPSIS
        Checks if a newer version of MealieSync is available on GitHub.
    .DESCRIPTION
        Queries the GitHub Releases API (cached for 24 hours) and compares
        the latest release version to the local module version.
        Returns $null silently on any error (offline, rate-limited, etc.).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    try {
        $cachePath = Join-Path ([System.IO.Path]::GetTempPath()) 'mealiesync-update-check.json'
        $manifestPath = Join-Path $PSScriptRoot '..' 'MealieApi.psd1'
        $manifest = Import-PowerShellDataFile $manifestPath
        $currentVersion = [version]$manifest.ModuleVersion

        $latestVersion = $null
        $releaseUrl = $null

        if (Test-Path $cachePath) {
            $cache = Get-Content $cachePath -Raw | ConvertFrom-Json
            $checkedAt = [datetime]::Parse($cache.checkedAt).ToUniversalTime()
            $age = (Get-Date).ToUniversalTime() - $checkedAt

            if ($age.TotalHours -lt 24) {
                $latestVersion = $cache.latestVersion
                $releaseUrl = $cache.releaseUrl
            }
        }

        if (-not $latestVersion) {
            $response = Invoke-RestMethod -Uri 'https://api.github.com/repos/Rouzax/MealieSync/releases/latest' -TimeoutSec 5 -ErrorAction Stop
            $tagName = $response.tag_name -replace '^v', ''
            $latestVersion = $tagName
            $releaseUrl = $response.html_url

            $cacheData = @{
                checkedAt     = (Get-Date).ToUniversalTime().ToString('o')
                latestVersion = $latestVersion
                releaseUrl    = $releaseUrl
            } | ConvertTo-Json

            [System.IO.File]::WriteAllText($cachePath, $cacheData, [System.Text.UTF8Encoding]::new($false))
        }

        $parsedLatest = [version]($latestVersion -replace '-.*$', '')

        return [PSCustomObject]@{
            UpdateAvailable = $parsedLatest -gt $currentVersion
            CurrentVersion  = $currentVersion.ToString()
            LatestVersion   = $latestVersion
            ReleaseUrl      = $releaseUrl
        }
    }
    catch {
        return $null
    }
}
