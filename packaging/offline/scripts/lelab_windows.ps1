param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("install", "start", "stop", "repair", "uninstall")]
    [string]$Action
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocationFile = Join-Path $env:LOCALAPPDATA "LeLab-zh-install-dir.txt"
$DefaultInstallDir = Join-Path $env:LOCALAPPDATA "LeLab-zh"

function Pause-ForUser {
    [void](Read-Host "按回车键继续")
}

function Fail([string]$Message) {
    Write-Host "[错误] $Message" -ForegroundColor Red
    Pause-ForUser
    exit 1
}

function Get-InstallDirectory {
    if (Test-Path -LiteralPath $LocationFile) {
        $saved = (Get-Content -LiteralPath $LocationFile -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
        if ($saved) { return $saved }
    }
    return $DefaultInstallDir
}

function Get-Executable([string]$InstallDir) {
    return Join-Path $InstallDir "venv\Scripts\lelab-zh.exe"
}

function Assert-NativeSuccess([string]$FailureMessage) {
    if ($LASTEXITCODE -ne 0) { throw $FailureMessage }
}

function Select-InstallDirectory {
    $suggested = Get-InstallDirectory
    Write-Host "[信息] 默认安装位置：$suggested"
    $inputPath = Read-Host "如需安装到其他本地磁盘，请输入完整路径；直接按回车使用默认位置"
    $selected = if ([string]::IsNullOrWhiteSpace($inputPath)) { $suggested } else { $inputPath.Trim() }

    try {
        $installDir = [System.IO.Path]::GetFullPath($selected).TrimEnd('\')
    } catch {
        Fail "安装位置无效。请使用例如 D:\LeLab-zh 的完整本地路径。"
    }

    if ($installDir -match '^\\\\') {
        Fail "不能安装到网络路径。请使用本机固定磁盘。"
    }

    $packageDir = [System.IO.Path]::GetFullPath($PackageRoot).TrimEnd('\')
    if ($installDir -eq $packageDir -or $installDir.StartsWith("$packageDir\", [System.StringComparison]::OrdinalIgnoreCase)) {
        Fail "不能安装到当前解压出的安装包文件夹。"
    }

    try {
        $drive = [System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($installDir))
    } catch {
        Fail "无法识别安装磁盘。请检查输入路径。"
    }
    if ($drive.DriveType -ne [System.IO.DriveType]::Fixed) {
        Fail "不能安装到 U 盘或其他可移动磁盘。"
    }
    if ($drive.AvailableFreeSpace -lt 30GB) {
        Fail "所选安装盘可用空间不足 30GB。"
    }
    return $installDir
}

function Assert-PackageComplete {
    foreach ($name in @("wheels", "runtime", "uv", "requirements-offline.txt")) {
        if (-not (Test-Path -LiteralPath (Join-Path $PackageRoot $name))) {
            Fail "安装文件不完整。请先将压缩包完整解压，再运行「一键安装」。"
        }
    }
}

function Test-PackageHashes {
    $manifest = Join-Path $PackageRoot "SHA256SUMS.txt"
    if (-not (Test-Path -LiteralPath $manifest)) { return }

    Write-Host "[信息] 正在校验文件完整性..."
    foreach ($line in Get-Content -LiteralPath $manifest -Encoding UTF8) {
        $parts = $line -split '  ', 2
        if ($parts.Count -ne 2) { throw "SHA256SUMS.txt 格式错误" }
        $file = Join-Path $PackageRoot $parts[1]
        if (-not (Test-Path -LiteralPath $file)) { throw "安装文件缺失：$($parts[1])" }
        $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $parts[0].ToLowerInvariant()) { throw "文件校验失败：$($parts[1])" }
    }
    Write-Host "[信息] 校验完成。"
}

function Install-LeLab {
    Write-Host "============================================================"
    Write-Host "  LeLab-zh 离线安装程序"
    Write-Host "============================================================"
    Write-Host ""

    if (-not [Environment]::Is64BitOperatingSystem) { Fail "此安装包仅支持 Windows 64 位系统。" }
    $installDir = Select-InstallDirectory
    Write-Host "[检查] 安装目录：$installDir"
    Assert-PackageComplete
    Test-PackageHashes

    if (Get-Command "nvidia-smi" -ErrorAction SilentlyContinue) {
        Write-Host "[信息] 检测到 NVIDIA 显卡或驱动，将启用 CUDA 加速。"
    } else {
        Write-Host "[警告] 未检测到 NVIDIA 显卡或驱动。"
        Write-Host "       将以 CPU 模式运行，训练会较慢；安装继续。"
    }

    $exe = Get-Executable $installDir
    if (Test-Path -LiteralPath $exe) { & $exe --stop *> $null }
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null

    Write-Host "[安装] 正在复制运行时文件..."
    foreach ($name in @("runtime", "uv", "wheels")) {
        $target = Join-Path $installDir $name
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        Copy-Item -LiteralPath (Join-Path $PackageRoot $name) -Destination $target -Recurse -Force
    }
    Copy-Item -LiteralPath (Join-Path $PackageRoot "requirements-offline.txt") -Destination (Join-Path $installDir "requirements-offline.txt") -Force

    $uv = Join-Path $installDir "uv\uv.exe"
    $python = Join-Path $installDir "runtime\python.exe"
    $venv = Join-Path $installDir "venv"
    Write-Host "[安装] 正在创建虚拟环境..."
    & $uv venv $venv --python $python
    Assert-NativeSuccess "创建虚拟环境失败。"

    Write-Host "[安装] 正在从本地安装依赖（此过程可能需要几分钟）..."
    & $uv pip install --python (Join-Path $venv "Scripts\python.exe") --offline --no-index --find-links (Join-Path $installDir "wheels") --require-hashes -r (Join-Path $installDir "requirements-offline.txt")
    Assert-NativeSuccess "依赖安装失败。请检查安装包是否完整。"

    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcut = Join-Path $desktop "Start LeLab.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($shortcut)
    $link.TargetPath = Get-Executable $installDir
    $link.WorkingDirectory = $installDir
    $link.Description = "LeLab-zh"
    $link.Save()

    Set-Content -LiteralPath (Join-Path $installDir "version.txt") -Value "v0.1.0" -Encoding UTF8
    Set-Content -LiteralPath $LocationFile -Value $installDir -Encoding UTF8
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  LeLab-zh 已安装到电脑本地。"
    Write-Host "============================================================"
    Write-Host "现在可以删除压缩包和解压文件夹，再从桌面的 Start LeLab 启动。"
    Pause-ForUser
}

function Start-LeLab {
    $exe = Get-Executable (Get-InstallDirectory)
    if (-not (Test-Path -LiteralPath $exe)) { Fail "LeLab-zh 未安装或安装不完整。请先运行「一键安装」。" }
    Write-Host "[启动] 正在启动 LeLab-zh..."
    Write-Host "[提示] 如果浏览器没有自动打开，请手动访问：http://127.0.0.1:8000"
    & $exe
    exit $LASTEXITCODE
}

function Stop-LeLab {
    $exe = Get-Executable (Get-InstallDirectory)
    if (-not (Test-Path -LiteralPath $exe)) { Fail "LeLab-zh 未安装。" }
    Write-Host "[停止] 正在停止 LeLab-zh..."
    & $exe --stop
    if ($LASTEXITCODE -eq 0) { Write-Host "[完成] LeLab-zh 已停止。" } else { Write-Host "[警告] 停止命令返回非零退出码。" }
    Pause-ForUser
}

function Repair-LeLab {
    $installDir = Get-InstallDirectory
    if (-not (Test-Path -LiteralPath (Join-Path $installDir "wheels"))) { Fail "本地修复文件不存在，请重新运行「一键安装」。" }
    $exe = Get-Executable $installDir
    if (Test-Path -LiteralPath $exe) { & $exe --stop *> $null }
    $venv = Join-Path $installDir "venv"
    $backup = Join-Path $installDir "venv.backup"
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
    $hadVenv = Test-Path -LiteralPath $venv
    if ($hadVenv) { Move-Item -LiteralPath $venv -Destination $backup }

    try {
        $uv = Join-Path $installDir "uv\uv.exe"
        & $uv venv $venv --python (Join-Path $installDir "runtime\python.exe")
        Assert-NativeSuccess "创建虚拟环境失败。"
        & $uv pip install --python (Join-Path $venv "Scripts\python.exe") --offline --no-index --find-links (Join-Path $installDir "wheels") --require-hashes -r (Join-Path $installDir "requirements-offline.txt")
        Assert-NativeSuccess "依赖安装失败。"
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
        Write-Host "[完成] 修复安装完成。"
    } catch {
        if (Test-Path -LiteralPath $venv) { Remove-Item -LiteralPath $venv -Recurse -Force }
        if ($hadVenv -and (Test-Path -LiteralPath $backup)) { Move-Item -LiteralPath $backup -Destination $venv }
        Fail "修复失败，已恢复旧环境。$($_.Exception.Message)"
    }
    Pause-ForUser
}

function Uninstall-LeLab {
    $installDir = Get-InstallDirectory
    Write-Host "[警告] 将删除 LeLab-zh 程序文件与桌面快捷方式。"
    Write-Host "用户数据集、HF 缓存、模型和训练结果不会被删除。"
    $confirm = Read-Host "确认卸载？(Y/N)"
    if ($confirm -notmatch '^[Yy]$') { Write-Host "卸载已取消。"; return }

    $exe = Get-Executable $installDir
    if (Test-Path -LiteralPath $exe) { & $exe --stop *> $null }
    Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath("Desktop")) "Start LeLab.lnk") -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $installDir) { Remove-Item -LiteralPath $installDir -Recurse -Force }
    Remove-Item -LiteralPath $LocationFile -Force -ErrorAction SilentlyContinue
    Write-Host "[完成] LeLab-zh 已卸载。"
    Pause-ForUser
}

try {
    switch ($Action) {
        "install" { Install-LeLab }
        "start" { Start-LeLab }
        "stop" { Stop-LeLab }
        "repair" { Repair-LeLab }
        "uninstall" { Uninstall-LeLab }
    }
} catch {
    Fail $_.Exception.Message
}
