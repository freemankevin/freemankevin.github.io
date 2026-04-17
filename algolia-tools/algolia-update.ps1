Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Algolia Search Index Update Tool    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 提示输入 Admin API Key
Write-Host "This script will update the Algolia search index." -ForegroundColor Yellow
Write-Host "You need to provide the Algolia Admin API Key." -ForegroundColor Yellow
Write-Host ""
Write-Host "Get your Admin API Key from:" -ForegroundColor White
Write-Host "  https://www.algolia.com/dashboard -> Settings -> API Keys" -ForegroundColor Gray
Write-Host ""

$ALGOLIA_KEY = Read-Host "Enter Algolia Admin API Key"

if ([string]::IsNullOrWhiteSpace($ALGOLIA_KEY)) {
    Write-Host "ERROR: API Key cannot be empty!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 1: Cleaning previous build..." -ForegroundColor Yellow
hexo clean

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: hexo clean failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Step 2: Generating site content..." -ForegroundColor Yellow
hexo generate

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: hexo generate failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Step 3: Updating Algolia index..." -ForegroundColor Yellow
$env:HEXO_ALGOLIA_INDEXING_KEY = $ALGOLIA_KEY
hexo algolia

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Algolia index update failed!" -ForegroundColor Red
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  - Invalid Admin API Key" -ForegroundColor Gray
    Write-Host "  - Network connection issue" -ForegroundColor Gray
    Write-Host "  - Algolia API rate limit exceeded" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Algolia Index Updated Successfully!   " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can verify the update at:" -ForegroundColor White
Write-Host "  https://www.algolia.com/dashboard" -ForegroundColor Gray
Write-Host ""

# 清除环境变量
$env:HEXO_ALGOLIA_INDEXING_KEY = $null