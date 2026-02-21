$sdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
$cmakeExe = "$sdkRoot\cmake\3.22.1\bin\cmake.exe"
$ndkRoot = "$sdkRoot\ndk\26.3.11579264"
$toolchain = "$ndkRoot\build\cmake\android.toolchain.cmake"
$srcDir = "$env:TEMP\libgit2_src"
$cppDir = "e:\spitHackathon\gitlane\android\app\src\main\cpp"
$env:PATH = "$sdkRoot\cmake\3.22.1\bin;" + $env:PATH

# ─── PATCH: Replace C_STANDARD 90 → 99 in libgit2 cmake files ──────────────
Write-Host "=== Patching libgit2 C_STANDARD 90 → 99 ===" -ForegroundColor Cyan
$filesToPatch = @(
    "$srcDir\src\libgit2\CMakeLists.txt",
    "$srcDir\src\util\CMakeLists.txt"
)
foreach ($f in $filesToPatch) {
    if (Test-Path $f) {
        (Get-Content $f -Raw) -replace 'C_STANDARD 90', 'C_STANDARD 99' | Set-Content $f -Encoding utf8 -NoNewline
        Write-Host "  Patched: $f" -ForegroundColor Green
    }
}

Write-Host "=== Copying headers ===" -ForegroundColor Cyan
$includeDir = "$cppDir\include"
New-Item -ItemType Directory -Force -Path $includeDir | Out-Null
Copy-Item "$srcDir\include\git2.h" $includeDir -Force
Copy-Item "$srcDir\include\git2"   $includeDir -Recurse -Force
Write-Host "  Headers copied." -ForegroundColor Green

$ABIS = @("arm64-v8a", "x86_64")

foreach ($ABI in $ABIS) {
    $buildDir = "$env:TEMP\libgit2_build7_$ABI"
    $outputDir = "$cppDir\jniLibs\$ABI"

    Remove-Item -Recurse -Force $buildDir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $buildDir  | Out-Null
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    Write-Host "=== Configure: $ABI ===" -ForegroundColor Cyan

    & $cmakeExe -S $srcDir -B $buildDir `
        "-DCMAKE_TOOLCHAIN_FILE=$toolchain" `
        "-DANDROID_ABI=$ABI" `
        "-DANDROID_PLATFORM=android-24" `
        "-DANDROID_STL=c++_static" `
        "-DCMAKE_BUILD_TYPE=Release" `
        "-DBUILD_SHARED_LIBS=OFF" `
        "-DBUILD_TESTS=OFF" `
        "-DUSE_SSH=OFF" `
        "-DUSE_HTTPS=OFF" `
        "-DUSE_OPENSSL=OFF" `
        "-DUSE_BUNDLED_ZLIB=ON" `
        "-DREGEX_BACKEND=builtin" `
        "-DUSE_HTTP_PARSER=builtin" `
        "-GNinja"

    if ($LASTEXITCODE -ne 0) { Write-Host "Configure FAILED for $ABI" -ForegroundColor Red; exit 1 }

    Write-Host "=== Build: $ABI ===" -ForegroundColor Cyan
    & $cmakeExe --build $buildDir
    if ($LASTEXITCODE -ne 0) { Write-Host "Build FAILED for $ABI" -ForegroundColor Red; exit 1 }

    $lib = Get-ChildItem -Recurse -Filter "libgit2.a" $buildDir | Select-Object -First 1
    if ($lib) {
        Copy-Item $lib.FullName "$outputDir\libgit2.a" -Force
        $size = [Math]::Round($lib.Length / 1KB)
        Write-Host "OK $ABI -> $outputDir\libgit2.a ($size KB)" -ForegroundColor Green
    }
    else {
        Write-Host "libgit2.a NOT found for $ABI!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "ALL DONE - libgit2 built for all ABIs" -ForegroundColor Green
