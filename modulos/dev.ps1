# Aba "Dev": atalhos para liberar RAM, limpar caches de dev e abrir ferramentas.
# O painel ja roda elevado; este modulo herda o admin e nao se auto-eleva.

function Add-AbaDev {
    param([Windows.Forms.TabControl]$tabs)

    $page = New-Object Windows.Forms.TabPage
    $page.Text = 'Dev'
    $page.UseVisualStyleBackColor = $true
    $tabs.TabPages.Add($page)

    # Pasta do painel = uma acima de modulos\ (onde este arquivo esta).
    $raiz = Split-Path $PSScriptRoot -Parent

    # ---------- Secao 1: Liberar RAM ----------
    $t1 = New-Object Windows.Forms.Label
    $t1.Text = 'Liberar RAM para tarefa pesada'
    $t1.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
    $t1.SetBounds(15, 8, 400, 22)
    $page.Controls.Add($t1)

    $bWsl = New-Object Windows.Forms.Button
    $bWsl.Text = 'Desligar WSL'
    $bWsl.SetBounds(15, 34, 190, 30)
    $page.Controls.Add($bWsl)

    $bDocker = New-Object Windows.Forms.Button
    $bDocker.Text = 'Parar Docker'
    $bDocker.SetBounds(215, 34, 190, 30)
    $page.Controls.Add($bDocker)

    $st1 = New-Object Windows.Forms.Label
    $st1.ForeColor = [Drawing.Color]::DimGray
    $st1.SetBounds(15, 68, 400, 22)
    $page.Controls.Add($st1)

    $bWsl.Add_Click({
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            $st1.Text = 'WSL nao instalado.'; return
        }
        try {
            wsl.exe --shutdown
            $st1.Text = 'WSL desligado.'
        } catch {
            $st1.Text = "Falhou ao desligar WSL: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    $bDocker.Add_Click({
        try {
            Stop-Process -Name 'Docker Desktop', 'com.docker.backend', 'com.docker.service' -Force -ErrorAction SilentlyContinue
            Stop-Service com.docker.service -ErrorAction SilentlyContinue
            $st1.Text = 'Docker parado (processos e servico).'
        } catch {
            $st1.Text = "Falhou ao parar Docker: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    # ---------- Secao 2: Limpar caches de dev ----------
    $t2 = New-Object Windows.Forms.Label
    $t2.Text = 'Limpar caches de dev'
    $t2.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
    $t2.SetBounds(15, 102, 400, 22)
    $page.Controls.Add($t2)

    $bNpm = New-Object Windows.Forms.Button
    $bNpm.Text = 'npm cache'
    $bNpm.SetBounds(15, 128, 125, 30)
    $page.Controls.Add($bNpm)

    $bPip = New-Object Windows.Forms.Button
    $bPip.Text = 'pip cache'
    $bPip.SetBounds(150, 128, 125, 30)
    $page.Controls.Add($bPip)

    $bNuget = New-Object Windows.Forms.Button
    $bNuget.Text = 'nuget'
    $bNuget.SetBounds(285, 128, 120, 30)
    $page.Controls.Add($bNuget)

    $st2 = New-Object Windows.Forms.Label
    $st2.ForeColor = [Drawing.Color]::DimGray
    $st2.SetBounds(15, 162, 400, 22)
    $page.Controls.Add($st2)

    $bNpm.Add_Click({
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            $st2.Text = 'npm nao instalado.'; return
        }
        try {
            npm cache clean --force 2>&1 | Out-Null
            $st2.Text = 'Cache do npm limpo.'
        } catch {
            $st2.Text = "Falhou no npm: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    $bPip.Add_Click({
        if (-not (Get-Command pip -ErrorAction SilentlyContinue)) {
            $st2.Text = 'pip nao instalado.'; return
        }
        try {
            pip cache purge 2>&1 | Out-Null
            $st2.Text = 'Cache do pip limpo.'
        } catch {
            $st2.Text = "Falhou no pip: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    $bNuget.Add_Click({
        if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
            $st2.Text = 'dotnet nao instalado.'; return
        }
        try {
            dotnet nuget locals all --clear 2>&1 | Out-Null
            $st2.Text = 'Cache NuGet limpo.'
        } catch {
            $st2.Text = "Falhou no nuget: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    # ---------- Secao 3: Abrir rapido ----------
    $t3 = New-Object Windows.Forms.Label
    $t3.Text = 'Abrir rapido'
    $t3.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
    $t3.SetBounds(15, 196, 400, 22)
    $page.Controls.Add($t3)

    $bTerm = New-Object Windows.Forms.Button
    $bTerm.Text = 'Terminal admin aqui'
    $bTerm.SetBounds(15, 222, 190, 30)
    $page.Controls.Add($bTerm)

    $bCode = New-Object Windows.Forms.Button
    $bCode.Text = 'VS Code no projeto'
    $bCode.SetBounds(215, 222, 190, 30)
    $page.Controls.Add($bCode)

    $bEnv = New-Object Windows.Forms.Button
    $bEnv.Text = 'Variaveis de ambiente'
    $bEnv.SetBounds(15, 258, 190, 30)
    $page.Controls.Add($bEnv)

    $bTask = New-Object Windows.Forms.Button
    $bTask.Text = 'Gerenciador de tarefas'
    $bTask.SetBounds(215, 258, 190, 30)
    $page.Controls.Add($bTask)

    $st3 = New-Object Windows.Forms.Label
    $st3.ForeColor = [Drawing.Color]::DimGray
    $st3.SetBounds(15, 294, 400, 22)
    $page.Controls.Add($st3)

    $bTerm.Add_Click({
        try {
            Start-Process powershell.exe -WorkingDirectory $raiz
            $st3.Text = "Terminal aberto em $raiz"
        } catch {
            $st3.Text = "Falhou ao abrir terminal: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    $bCode.Add_Click({
        if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
            $st3.Text = 'VS Code (code) nao encontrado no PATH.'; return
        }
        try {
            Start-Process code $raiz
            $st3.Text = 'VS Code aberto no projeto.'
        } catch {
            $st3.Text = "Falhou ao abrir VS Code: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    $bEnv.Add_Click({
        try {
            Start-Process rundll32.exe 'sysdm.cpl,EditEnvironmentVariables'
            $st3.Text = 'Editor de variaveis aberto.'
        } catch {
            $st3.Text = "Falhou: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    $bTask.Add_Click({
        try {
            Start-Process taskmgr.exe
            $st3.Text = 'Gerenciador de tarefas aberto.'
        } catch {
            $st3.Text = "Falhou: $($_.Exception.Message)"
        }
    }.GetNewClosure())
}
