# Aba "Sistema": monitor rapido (RAM/CPU/disco/temperatura), troca de plano de energia
# e quick fixes (reiniciar Explorer, audio e spooler). O painel ja roda elevado; nada se auto-eleva.

# Origem = GUID do esquema oculto a duplicar se o plano nao existir (Ultimate).
# Equilibrado e Alto desempenho sao builtin: o setactive ja os revela, Origem = $null.
# O Desempenho Maximo (Ultimate) nao ativa direto neste SKU: duplicamos e9a42b02 sempre
# para um GUID FIXO (idempotente - se ja existir, o duplicatescheme recusa e seguimos).
$script:SistemaPlanos = @(
    @{ Nome = 'Equilibrado';       Guid = '381b4222-f694-41f0-9685-ff5bb260df2e'; Origem = $null }
    @{ Nome = 'Alto desempenho';   Guid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'; Origem = $null }
    @{ Nome = 'Desempenho Maximo'; Guid = 'c5e9b8a1-0e2f-4b6d-9a3c-7f1e2d4b6a80'; Origem = 'e9a42b02-d5df-448d-aa00-03f14749eb61' }
)

function Set-SistemaPlano($plano) {
    # Tenta ativar direto; se nao pegou e ha Origem, duplica o esquema oculto e ativa.
    powercfg /setactive $plano.Guid 2>$null | Out-Null
    $ativo = (powercfg /getactivescheme) -join ' '
    if ($ativo -notmatch $plano.Guid -and $plano.Origem) {
        powercfg -duplicatescheme $plano.Origem $plano.Guid 2>$null | Out-Null
        powercfg /setactive $plano.Guid 2>$null | Out-Null
        $ativo = (powercfg /getactivescheme) -join ' '
    }
    return ($ativo -match $plano.Guid)
}

function Get-SistemaTempCpu {
    # Best-effort: nem toda maquina expoe a thermal zone via WMI. CurrentTemperature vem
    # em decimos de Kelvin. Falhou ou nao existe -> "n/d". Nao instala nada.
    try {
        $t = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop |
            Select-Object -First 1 -ExpandProperty CurrentTemperature
        if ($null -eq $t) { return 'n/d' }
        $c = [math]::Round($t / 10 - 273.15, 1)
        return "$c " + [char]0x00B0 + 'C'
    } catch {
        return 'n/d'
    }
}

function Add-AbaSistema {
    param([Windows.Forms.TabControl]$tabs)

    $page = New-Object Windows.Forms.TabPage
    $page.Text = 'Sistema'
    $page.UseVisualStyleBackColor = $true
    $tabs.TabPages.Add($page)

    # --- Secao 1: Monitor rapido ---
    $tituloMon = New-Object Windows.Forms.Label
    $tituloMon.Text = 'Monitor rapido'
    $tituloMon.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
    $tituloMon.SetBounds(15, 10, 200, 22)
    $page.Controls.Add($tituloMon)

    $lblRam = New-Object Windows.Forms.Label
    $lblRam.SetBounds(15, 36, 290, 20)
    $page.Controls.Add($lblRam)

    $lblCpu = New-Object Windows.Forms.Label
    $lblCpu.SetBounds(15, 58, 290, 20)
    $page.Controls.Add($lblCpu)

    $lblDisco = New-Object Windows.Forms.Label
    $lblDisco.SetBounds(15, 80, 290, 20)
    $page.Controls.Add($lblDisco)

    $lblTemp = New-Object Windows.Forms.Label
    $lblTemp.SetBounds(15, 102, 290, 20)
    $page.Controls.Add($lblTemp)

    $btnAtualizar = New-Object Windows.Forms.Button
    $btnAtualizar.Text = 'Atualizar'
    $btnAtualizar.SetBounds(310, 40, 105, 30)
    $page.Controls.Add($btnAtualizar)

    $lerMonitor = {
        try {
            $os = Get-CimInstance Win32_OperatingSystem
            $totalMb = $os.TotalVisibleMemorySize / 1024
            $usadaMb = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024
            $lblRam.Text = 'RAM: {0:N1} / {1:N1} GB usada' -f ($usadaMb / 1024), ($totalMb / 1024)
        } catch { $lblRam.Text = 'RAM: n/d' }

        try {
            $load = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
            $lblCpu.Text = 'CPU: {0:N0} %' -f $load
        } catch { $lblCpu.Text = 'CPU: n/d' }

        try {
            $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
            $lblDisco.Text = 'Disco C: {0:N1} livre / {1:N1} GB total' -f ($d.FreeSpace / 1GB), ($d.Size / 1GB)
        } catch { $lblDisco.Text = 'Disco C: n/d' }

        $lblTemp.Text = 'Temperatura CPU: ' + (Get-SistemaTempCpu)
    }.GetNewClosure()

    $btnAtualizar.Add_Click($lerMonitor)

    # --- Secao 2: Plano de energia ---
    $tituloPlano = New-Object Windows.Forms.Label
    $tituloPlano.Text = 'Plano de energia'
    $tituloPlano.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
    $tituloPlano.SetBounds(15, 135, 200, 22)
    $page.Controls.Add($tituloPlano)

    $lblPlano = New-Object Windows.Forms.Label
    $lblPlano.SetBounds(15, 161, 400, 20)
    $lblPlano.ForeColor = [Drawing.Color]::DimGray
    $page.Controls.Add($lblPlano)

    $lerPlano = {
        try {
            $ativo = (powercfg /getactivescheme) -join ' '
            $nome = ($script:SistemaPlanos | Where-Object { $ativo -match $_.Guid } | Select-Object -First 1).Nome
            if (-not $nome) { $nome = ($ativo -replace '.*\((.*)\).*', '$1') }
            $lblPlano.Text = 'Plano ativo: ' + $nome
        } catch { $lblPlano.Text = 'Plano ativo: n/d' }
    }.GetNewClosure()

    # Um botao por plano (Equilibrado / Alto desempenho / Desempenho Maximo).
    $x = 15
    foreach ($plano in $script:SistemaPlanos) {
        $btn = New-Object Windows.Forms.Button
        $btn.Text = $plano.Nome
        $btn.SetBounds($x, 185, 138, 32)
        $page.Controls.Add($btn)
        $btn.Add_Click({
            try {
                if (-not (Set-SistemaPlano $plano)) {
                    $lblPlano.Text = 'Nao foi possivel ativar: ' + $plano.Nome
                    $lblPlano.ForeColor = [Drawing.Color]::Firebrick
                    return
                }
                $lblPlano.ForeColor = [Drawing.Color]::DimGray
            } catch {
                $lblPlano.Text = 'Erro ao trocar plano: ' + $_.Exception.Message
                $lblPlano.ForeColor = [Drawing.Color]::Firebrick
                return
            }
            & $lerPlano
        }.GetNewClosure())
        $x += 143
    }

    # --- Secao 3: Quick fixes ---
    $tituloFix = New-Object Windows.Forms.Label
    $tituloFix.Text = 'Quick fixes'
    $tituloFix.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
    $tituloFix.SetBounds(15, 230, 200, 22)
    $page.Controls.Add($tituloFix)

    $lblStatus = New-Object Windows.Forms.Label
    $lblStatus.SetBounds(15, 300, 400, 40)
    $lblStatus.ForeColor = [Drawing.Color]::DimGray
    $page.Controls.Add($lblStatus)

    $btnExplorer = New-Object Windows.Forms.Button
    $btnExplorer.Text = 'Reiniciar Explorer'
    $btnExplorer.SetBounds(15, 256, 128, 34)
    $page.Controls.Add($btnExplorer)
    $btnExplorer.Add_Click({
        try {
            Stop-Process -Name explorer -Force
            $lblStatus.Text = 'Explorer reiniciado.'
        } catch { $lblStatus.Text = 'Falha ao reiniciar Explorer: ' + $_.Exception.Message }
    }.GetNewClosure())

    $btnAudio = New-Object Windows.Forms.Button
    $btnAudio.Text = 'Reiniciar audio'
    $btnAudio.SetBounds(151, 256, 128, 34)
    $page.Controls.Add($btnAudio)
    $btnAudio.Add_Click({
        try {
            Restart-Service AudioEndpointBuilder -Force
            Restart-Service Audiosrv -Force
            $lblStatus.Text = 'Audio reiniciado.'
        } catch { $lblStatus.Text = 'Falha ao reiniciar audio: ' + $_.Exception.Message }
    }.GetNewClosure())

    $btnSpooler = New-Object Windows.Forms.Button
    $btnSpooler.Text = 'Reiniciar spooler'
    $btnSpooler.SetBounds(287, 256, 128, 34)
    $page.Controls.Add($btnSpooler)
    $btnSpooler.Add_Click({
        try {
            Restart-Service Spooler -Force
            $lblStatus.Text = 'Spooler reiniciado.'
        } catch { $lblStatus.Text = 'Falha ao reiniciar spooler: ' + $_.Exception.Message }
    }.GetNewClosure())

    # Leitura inicial ao abrir a aba.
    & $lerMonitor
    & $lerPlano
}
