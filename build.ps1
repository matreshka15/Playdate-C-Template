# Playdate C Game Build Script for Windows
# 使用方法: .\build.ps1

param(
    [switch]$Clean,
    [switch]$Run
)

$ErrorActionPreference = "Stop"

# 配置
$SDK_PATH = "D:\APP\PlaydateSDK"
$PROJECT_NAME = "MyPlaydateGame"
$SOURCE_DIR = "src"
$BUILD_DIR = "build"
$OUTPUT_DIR = "."

# 颜色输出函数
function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }

Write-Info "=== Playdate Game Builder ==="
Write-Info "项目: $PROJECT_NAME"

# 检查 SDK 路径
if (-not (Test-Path $SDK_PATH)) {
    Write-Error "错误: 找不到 Playdate SDK: $SDK_PATH"
    exit 1
}

Write-Info "SDK 路径: $SDK_PATH"

# 清理
if ($Clean) {
    Write-Info "清理构建文件..."
    if (Test-Path $BUILD_DIR) { Remove-Item -Recurse -Force $BUILD_DIR }
    if (Test-Path "$OUTPUT_DIR\$PROJECT_NAME.pdx") { Remove-Item -Recurse -Force "$OUTPUT_DIR\$PROJECT_NAME.pdx" }
    Write-Success "清理完成!"
    if (-not $Run) { exit 0 }
}

# 创建构建目录
if (-not (Test-Path $BUILD_DIR)) {
    New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
}

# 查找 Visual Studio
Write-Info "查找 Visual Studio 2022..."
$vsPath = "C:\Program Files\Microsoft Visual Studio\2022"
$vcvarsPath = $null

foreach ($edition in @("Enterprise", "Professional", "Community")) {
    $testPath = "$vsPath\$edition\VC\Auxiliary\Build\vcvars64.bat"
    if (Test-Path $testPath) {
        $vcvarsPath = $testPath
        Write-Success "找到 Visual Studio 2022 $edition"
        break
    }
}

if (-not $vcvarsPath) {
    Write-Error "错误: 找不到 Visual Studio 2022"
    Write-Info "请安装 Visual Studio 2022 并包含 'C++ 桌面开发' 工作负载"
    exit 1
}

# 收集源文件
$sourceFiles = Get-ChildItem -Path $SOURCE_DIR -Filter *.c -Recurse | ForEach-Object { $_.FullName }
Write-Info "找到 $($sourceFiles.Count) 个源文件"

# 生成编译命令
$includes = "/I`"$SDK_PATH\C_API`""
$defines = "/DTARGET_PLAYDATE=1 /DTARGET_EXTENSION=1 /DTARGET_SIMULATOR=1 /D_WINDLL"
$compilerFlags = "/c /nologo /W3 /Z7 /Od /MD"
$linkerFlags = "/DLL /NOLOGO /DEBUG /INCREMENTAL:NO /EXPORT:eventHandler"

# 编译源文件
Write-Info "`n编译源文件..."
$objFiles = @()

foreach ($sourceFile in $sourceFiles) {
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile)
    $objFile = "$BUILD_DIR\$fileName.obj"
    $objFiles += $objFile

    Write-Host "  编译: $([System.IO.Path]::GetFileName($sourceFile))"

    # 创建批处理命令
    $batchContent = @"
@echo off
call "$vcvarsPath"
cl $compilerFlags $defines $includes "$sourceFile" /Fo:"$objFile"
"@
    $batchFile = "$BUILD_DIR\compile_$fileName.bat"
    Set-Content -Path $batchFile -Value $batchContent

    $result = & cmd /c $batchFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "编译失败: $fileName.c"
        Write-Host $result
        exit 1
    }
}

Write-Success "编译完成!"

# 链接
Write-Info "`n链接动态库..."
$dllFile = "$BUILD_DIR\pdex.dll"
$objList = ($objFiles | ForEach-Object { "`"$_`"" }) -join " "

# 创建批处理命令
$batchContent = @"
@echo off
call "$vcvarsPath"
link $linkerFlags $objList /OUT:"$dllFile"
"@
$batchFile = "$BUILD_DIR\link.bat"
Set-Content -Path $batchFile -Value $batchContent

$result = & cmd /c $batchFile 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "链接失败!"
    Write-Host $result
    exit 1
}

Write-Success "链接完成!"

# 使用 pdc 打包
Write-Info "`n打包游戏..."
$pdcPath = "$SDK_PATH\bin\pdc.exe"

if (-not (Test-Path $pdcPath)) {
    Write-Error "错误: 找不到 pdc.exe"
    exit 1
}

# 创建临时目录结构
$tempDir = "$BUILD_DIR\temp_game"
if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Path $tempDir | Out-Null

# 复制 DLL
Copy-Item $dllFile "$tempDir\pdex.dll"

# 创建 pdxinfo 文件
$pdxinfo = @"
name=$PROJECT_NAME
author=Developer
description=My Playdate Game
bundleID=com.example.$PROJECT_NAME
version=1.0.0
buildNumber=1
"@
Set-Content -Path "$tempDir\pdxinfo" -Value $pdxinfo

# 运行 pdc
$outputPdx = "$OUTPUT_DIR\$PROJECT_NAME.pdx"
& $pdcPath $tempDir $outputPdx 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputPdx)) {
    Write-Error "pdc 打包失败!"
    exit 1
}

Write-Success "打包完成: $PROJECT_NAME.pdx"

# 运行游戏
if ($Run) {
    Write-Info "`n启动 Playdate 模拟器..."
    $simulatorPath = "$SDK_PATH\bin\PlaydateSimulator.exe"

    if (-not (Test-Path $simulatorPath)) {
        Write-Error "错误: 找不到 PlaydateSimulator.exe"
        exit 1
    }

    Start-Process -FilePath $simulatorPath -ArgumentList "`"$outputPdx`""
    Write-Success "模拟器已启动!"
}

Write-Success "`n=== 构建成功! ==="
