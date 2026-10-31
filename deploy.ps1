# Find the active PostGIS/Postgres container name dynamically from Docker
$containerId = (docker ps --filter "ancestor=postgis/postgis" --format "{{.ID}}") | Select-Object -First 1

if (-not $containerId) {
    # Fallback to checking any running container with postgres in the name
    $containerId = (docker ps --format "{{.ID}} {{.Names}}" | Select-String -Pattern "postgres|postgis|db" | Select-Object -First 1).Line.Split(" ")[0]
}

if (-not $containerId) {
    Write-Host "[ERROR] No running PostgreSQL/PostGIS Docker container found! Please ensure your Docker container is started." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Target Docker Container ID: $containerId" -ForegroundColor Green

# Define ordered execution pipeline for 1.SQL
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
        Write-Host "[EXEC] Running $file inside container..." -ForegroundColor Cyan
        
        # Read local file content and pipe it straight into docker exec psql
        Get-Content $filePath -Raw | docker exec -i $containerId psql -U postgres -d campus_delivery
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[WARNING] Execution of $file finished with exit code $LASTEXITCODE" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[SKIP] $file not found in 1.SQL folder." -ForegroundColor Yellow
    }
}

Write-Host "[SUCCESS] Complete database schema, seeds, indexes, and triggers deployed to Docker PostgreSQL!" -ForegroundColor Green
