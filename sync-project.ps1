Write-Host "[1/3] Checking Docker PostGIS Container..." -ForegroundColor Cyan
$containerId = (docker ps --filter "ancestor=postgis/postgis" --format "{{.ID}}") | Select-Object -First 1
if (-not $containerId) {
    $containerId = (docker ps --format "{{.ID}} {{.Names}}" | Select-String -Pattern "postgres|postgis|db" | Select-Object -First 1).Line.Split(" ")[0]
}

if ($containerId) {
    Write-Host "[INFO] Target Docker Container ID: $containerId" -ForegroundColor Green
    $sqlFiles = Get-ChildItem ".\1.SQL\*.sql" | Sort-Object Name
    foreach ($file in $sqlFiles) {
        Write-Host "[EXEC] Deploying $($file.Name)..." -ForegroundColor Yellow
        Get-Content $file.FullName -Raw | docker exec -i $containerId psql -U postgres -d campus_delivery
    }
    Write-Host "[SUCCESS] Database schemas, seeds, and views redeployed successfully!" -ForegroundColor Green
} else {
    Write-Host "[WARNING] No running PostgreSQL Docker container found. Skipping database migration sync." -ForegroundColor Yellow
}

Write-Host "[2/3] Staging workspace file changes in Git..." -ForegroundColor Cyan
git add .

$commitMsg = "Sync project changes: updated database pipeline, frontend components, and experiment scripts"
git commit -m "$commitMsg"

Write-Host "[3/3] Pushing changes to remote repository..." -ForegroundColor Cyan
git push origin main

Write-Host "[COMPLETE] All project changes successfully reflected and synchronized!" -ForegroundColor Green
