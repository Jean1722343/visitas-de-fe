# Publica una versión nueva: todos los teléfonos la descargan e instalan solos.
#
# Uso (desde la carpeta del proyecto, en PowerShell):
#   .\publicar.ps1 1.0.1 "Qué cambió en esta versión"
#
# 1. Sube la versión en pubspec.yaml (y el número de compilación).
# 2. Compila el APK firmado con la llave propia (android/key.properties).
# 3. Guarda los cambios en git y los sube a GitHub.
# 4. Crea el release v<versión> con el APK. Al abrir la app, cada teléfono
#    lo detecta, lo descarga y abre el instalador.

param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Notas = "Mejoras y correcciones."
)
$ErrorActionPreference = "Stop"
$flutter = "C:\Users\jpgcp\flutter\bin\flutter.bat"

if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "La versión debe ser como 1.0.1" }
if (-not (Test-Path "android\key.properties")) { throw "Falta android\key.properties (la llave de firma)." }

# 1. Versión
$pubspec = Get-Content pubspec.yaml -Raw
$m = [regex]::Match($pubspec, '(?m)^version:\s*([\d\.]+)\+(\d+)')
$compilacion = [int]$m.Groups[2].Value + 1
$pubspec = $pubspec -replace '(?m)^version:.*$', "version: $Version+$compilacion"
[IO.File]::WriteAllText("$PWD\pubspec.yaml", $pubspec)
Write-Host "Versión $Version (compilación $compilacion)"

# 2. Compilar
& $flutter test
if ($LASTEXITCODE -ne 0) { throw "Las pruebas fallaron; no se publica." }
& $flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "No compiló." }
$apk = "build\visitas-de-fe.apk"
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" $apk -Force

# 3. Git
git add -A
git commit -m "Versión $Version" -m $Notas
git push -u origin HEAD

# 4. Release
gh release create "v$Version" $apk --title "Versión $Version" --notes $Notas
Write-Host "Listo: v$Version publicada. Los teléfonos se actualizarán al abrir la app."
