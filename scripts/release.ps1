#!/usr/bin/env pwsh
<#
.SYNOPSIS
    MonsterPi Release Helper CLI
.DESCRIPTION
    Interactive CLI to manage MonsterPi releases with GitVersion integration
#>

param()

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Confirm-Action {
    param([string]$Prompt)
    $response = Read-Host "$Prompt (y/n)"
    return $response -eq 'y' -or $response -eq 'Y'
}

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Error "Error: Not in a git repository. Please run this script from the repository root."
    exit 1
}

Write-Info "MonsterPi Release Helper"
Write-Info "========================"
Write-Host ""

# 1. Check if we're on main branch
Write-Info "Checking current branch..."
$currentBranch = git rev-parse --abbrev-ref HEAD
if ($currentBranch -ne "main") {
    Write-Error "Error: Not on 'main' branch. Current branch: $currentBranch"
    Write-Info "Please switch to main branch first: git checkout main"
    exit 1
}
Write-Success "On main branch"
Write-Host ""

# 2. Run GitVersion and get FullSemVer
Write-Info "Running GitVersion..."
$gitVersionOutput = dotnet-gitversion | ConvertFrom-Json
if (-not $gitVersionOutput) {
    Write-Error "Error: Failed to run GitVersion. Make sure GitVersion is installed."
    Write-Info "Install with: dotnet tool install --global GitVersion.Tool"
    exit 1
}

$fullSemVer = $gitVersionOutput.FullSemVer
$majorMinorPatch = $gitVersionOutput.MajorMinorPatch
Write-Success "GitVersion FullSemVer: $fullSemVer"
Write-Success "GitVersion MajorMinorPatch: $majorMinorPatch"
Write-Host ""

# 3. Read DIST_VERSION from src/config
Write-Info "Reading DIST_VERSION from src/config..."
$configPath = "src/config"
if (-not (Test-Path $configPath)) {
    Write-Error "Error: src/config file not found"
    exit 1
}

$distVersion = $null
Get-Content $configPath | ForEach-Object {
    if ($_ -match '^export DIST_VERSION=(.+)$') {
        $distVersion = $matches[1]
    }
}

if (-not $distVersion) {
    Write-Error "Error: Could not find DIST_VERSION in src/config"
    exit 1
}
Write-Success "DIST_VERSION in config: $distVersion"
Write-Host ""

# 4. Check if versions are in sync
if ($distVersion -ne $majorMinorPatch) {
    Write-Warning "Version mismatch detected!"
    Write-Host "  Config DIST_VERSION: $distVersion"
    Write-Host "  GitVersion MajorMinorPatch: $majorMinorPatch"
    Write-Host ""

    if (Confirm-Action "Would you like to update src/config to $majorMinorPatch?") {
        Write-Info "Updating src/config..."

        # Update the config file
        $configContent = Get-Content $configPath -Raw
        $configContent = $configContent -replace "(export DIST_VERSION=).*", "`$1$majorMinorPatch"
        Set-Content -Path $configPath -Value $configContent -NoNewline

        Write-Success "Updated DIST_VERSION to $majorMinorPatch"

        # Commit the change
        if (Confirm-Action "Would you like to commit this change?") {
            git add $configPath
            git commit -m "chore: bump version to $majorMinorPatch"
            Write-Success "Committed version update"
            Write-Host ""
            Write-Info "Please push this commit and re-run the release script."
            Write-Host "  git push origin main"
        } else {
            Write-Warning "Changes staged but not committed. Please commit manually."
        }
    } else {
        Write-Info "Exiting without changes."
    }

    exit 0
}

Write-Success "Versions are in sync!"
Write-Host ""

# 5. Check if release branch already exists
$releaseBranch = "release/$majorMinorPatch"
Write-Info "Checking if release branch exists..."

$branchExists = git show-ref --verify --quiet "refs/heads/$releaseBranch"
if ($LASTEXITCODE -eq 0) {
    Write-Error "Error: Release branch '$releaseBranch' already exists"
    Write-Info "To recreate it, delete the branch first:"
    Write-Host "  git branch -D $releaseBranch"
    exit 1
}

$remoteBranchExists = git ls-remote --heads origin $releaseBranch | Select-String $releaseBranch
if ($remoteBranchExists) {
    Write-Error "Error: Release branch '$releaseBranch' already exists on remote"
    exit 1
}

Write-Success "Release branch does not exist"
Write-Host ""

# 6. Offer to create release branch
Write-Info "Ready to create release branch: $releaseBranch"
Write-Host ""

if (Confirm-Action "Would you like to create the release branch now?") {
    Write-Info "Creating release branch..."
    git checkout -b $releaseBranch

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Created release branch: $releaseBranch"
        Write-Host ""
        Write-Info "Next steps:"
        Write-Host "  1. Review the branch and make any necessary changes"
        Write-Host "  2. When ready, push the branch with:"
        Write-Host ""
        Write-Success "     git push origin $releaseBranch"
        Write-Host ""
        Write-Info "  3. This will trigger the release workflow automatically"
    } else {
        Write-Error "Failed to create release branch"
        exit 1
    }
} else {
    Write-Info "Release branch not created. Exiting."
    exit 0
}
