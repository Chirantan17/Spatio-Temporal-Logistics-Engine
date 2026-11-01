$containerName = "spatio-temporal-logistics-engine-db"

$check = docker ps --filter "name=$containerName" --format "{{.Names}}"
if (-not $check) {
    Write-Host "[ERROR] Container $containerName is not running. Starting it..." -ForegroundColor Yellow
    cd .\4.Requirements
    docker compose -p spatio-temporal-logistics-engine up -d
    cd ..
    Start-Sleep -Seconds 4
}

Write-Host "[INFO] Target Container: $containerName" -ForegroundColor Green

# Recreate fresh campus_delivery from default 'postgres' database
Write-Host "[INIT] Recreating fresh 'campus_delivery' database..." -ForegroundColor Yellow
$initSql = @"
REVOKE CONNECT ON DATABASE campus_delivery FROM public;
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'campus_delivery' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS campus_delivery;
CREATE DATABASE campus_delivery;
\c campus_delivery
CREATE EXTENSION IF NOT EXISTS postgis;
"@
$initSql | docker exec -i $containerName psql -U postgres -d postgres

$sqlFiles = @(
    "01_schema.sql",
    "02_seed.sql",
    "03_basic_queries.sql",
    "04_spatial_queries.sql",
    "05_temporal_queries.sql",
    "06_spatiotemporal_queries.sql",
    "07_order_lifecycle.sql",
    "08_analytical_queries.sql",
    "09_indexing_optimizations.sql",
    "10_custom_investigation.sql",
    "11_security_triggers.sql",
    "12_concurrency_stress_test.sql",
    "13_database_views.sql"
)

foreach ($file in $sqlFiles) {
    $filePath = ".\1.SQL\$file"
    if (Test-Path $filePath) {
        Write-Host "[EXEC] Deploying $file..." -ForegroundColor Cyan
        Get-Content $filePath -Raw | docker exec -i $containerName psql -U postgres -d campus_delivery -v ON_ERROR_STOP=1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Failed executing $file" -ForegroundColor Red
            exit $LASTEXITCODE
        }
    }
}

Write-Host "`n[SUCCESS] All 13 SQL pipelines deployed cleanly with 0 errors to $containerName!" -ForegroundColor Green
