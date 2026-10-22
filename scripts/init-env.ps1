$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root ".env"

if (Test-Path $envFile) {
    throw ".env already exists. Keeping existing credentials; remove it manually only if you intend to rotate them."
}

function New-Secret {
    $bytes = New-Object byte[] 24
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    } finally {
        $generator.Dispose()
    }
    return -join ($bytes | ForEach-Object { $_.ToString("x2") })
}

$lines = @(
    "COMPOSE_PROJECT_NAME=billing-system",
    "POSTGRES_USER=billing_admin",
    "POSTGRES_PASSWORD=$(New-Secret)",
    "APP_DB_PASSWORD=$(New-Secret)",
    "METRICS_DB_PASSWORD=$(New-Secret)",
    "PGADMIN_DEFAULT_EMAIL=admin@example.com",
    "PGADMIN_DEFAULT_PASSWORD=$(New-Secret)",
    "GRAFANA_ADMIN_USER=admin",
    "GRAFANA_ADMIN_PASSWORD=$(New-Secret)"
)
Set-Content -Path $envFile -Value $lines -Encoding ascii
Write-Host "Created .env with random credentials. Keep it private; it is excluded from Git."
