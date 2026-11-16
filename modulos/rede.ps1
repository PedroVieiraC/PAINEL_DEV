# Aba "Rede": matar porta em uso, utilitarios de rede (flush DNS, renovar IP,
# reset Winsock) e troca rapida de DNS no adaptador ativo.
# O painel ja roda elevado; nenhum modulo chama RunAs por conta propria.

function Get-PidsDaPorta([int]$porta) {
    # Prefere Get-NetTCPConnection; fallback para netstat -ano se o cmdlet nao existir/falhar.
    try {
        $conns = Get-NetTCPConnection -LocalPort $porta -ErrorAction Stop
        return @($conns | Select-Object -ExpandProperty OwningProcess -Unique)
    } catch {
        $linhas = netstat -ano | Select-String -Pattern "[:.]$porta\s"
        $pids = foreach ($l in $linhas) {
            $campos = ($l.ToString().Trim() -split '\s+')
            if ($campos[1] -match "[:.]$porta$") { $campos[-1] }
        }
        return @($pids | Where-Object { $_ -match '^\d+$' -and $_ -ne '0' } | Select-Object -Unique)
    }
}

function Add-AbaRede {
    param([Windows.Forms.TabControl]$tabs)

    $page = New-Object Windows.Forms.TabPage
    $page.Text = 'Rede'
    $page.UseVisualStyleBackColor = $true
    $tabs.TabPages.Add($page)

    # --- 1) Matar porta em uso ---
    $lblPorta = New-Object Windows.Forms.Label
    $lblPorta.Text = 'Matar porta em uso:'
    $lblPorta.SetBounds(15, 12, 150, 22)
    $page.Controls.Add($lblPorta)

    $txtPorta = New-Object Windows.Forms.TextBox
    $txtPorta.SetBounds(170, 10, 90, 24)
    $page.Controls.Add($txtPorta)

    $btnPorta = New-Object Windows.Forms.Button
    $btnPorta.Text = 'Matar porta'
    $btnPorta.SetBounds(270, 9, 140, 28)
    $page.Controls.Add($btnPorta)

    $stPorta = New-Object Windows.Forms.Label
    $stPorta.SetBounds(15, 42, 400, 40)
    $stPorta.ForeColor = [Drawing.Color]::DimGray
    $page.Controls.Add($stPorta)

    $btnPorta.Add_Click({
        try {
            $texto = $txtPorta.Text.Trim()
            $porta = 0
            if (-not [int]::TryParse($texto, [ref]$porta) -or $porta -lt 1 -or $porta -gt 65535) {
                $stPorta.Text = 'Informe uma porta valida (1 a 65535).'
                return
            }
            $pids = Get-PidsDaPorta $porta
            if (-not $pids -or $pids.Count -eq 0) {
                $stPorta.Text = "Porta $porta nao esta em uso."
                return
            }
            $procs = foreach ($procId in $pids) { Get-Process -Id $procId -ErrorAction SilentlyContinue }
            $procs = @($procs | Where-Object { $_ })
            if ($procs.Count -eq 0) {
                $stPorta.Text = "Porta ${porta}: PID encontrado mas processo ja nao existe."
                return
            }
            $lista = ($procs | ForEach-Object { "$($_.ProcessName) (PID $($_.Id))" }) -join [Environment]::NewLine
            $r = [Windows.Forms.MessageBox]::Show(
                "Porta $porta usada por:" + [Environment]::NewLine + $lista + [Environment]::NewLine + [Environment]::NewLine + 'Encerrar?',
                'Matar porta', 'YesNo', 'Warning')
            if ($r -ne 'Yes') { $stPorta.Text = 'Cancelado.'; return }
            $mortos = @()
            foreach ($p in $procs) {
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
                $mortos += "$($p.ProcessName) (PID $($p.Id))"
            }
            $stPorta.Text = "Encerrado: " + ($mortos -join ', ')
        } catch {
            $stPorta.Text = "Falhou: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    # --- 2) Botoes de rede ---
    $stUtil = New-Object Windows.Forms.Label
    $stUtil.SetBounds(15, 135, 400, 40)
    $stUtil.ForeColor = [Drawing.Color]::DimGray
    $page.Controls.Add($stUtil)

    $btnFlush = New-Object Windows.Forms.Button
    $btnFlush.Text = 'Flush DNS'
    $btnFlush.SetBounds(15, 95, 125, 32)
    $page.Controls.Add($btnFlush)
    $btnFlush.Add_Click({
        try {
            ipconfig /flushdns | Out-Null
            $stUtil.Text = 'Cache DNS limpo.'
        } catch { $stUtil.Text = "Falhou: $($_.Exception.Message)" }
    }.GetNewClosure())

    $btnRenovar = New-Object Windows.Forms.Button
    $btnRenovar.Text = 'Renovar IP'
    $btnRenovar.SetBounds(150, 95, 125, 32)
    $page.Controls.Add($btnRenovar)
    $btnRenovar.Add_Click({
        try {
            $stUtil.Text = 'Renovando IP... a conexao pode cair por instantes.'
            ipconfig /release | Out-Null
            ipconfig /renew | Out-Null
            $stUtil.Text = 'IP liberado e renovado.'
        } catch { $stUtil.Text = "Falhou: $($_.Exception.Message)" }
    }.GetNewClosure())

    $btnWinsock = New-Object Windows.Forms.Button
    $btnWinsock.Text = 'Reset Winsock'
    $btnWinsock.SetBounds(285, 95, 125, 32)
    $page.Controls.Add($btnWinsock)
    $btnWinsock.Add_Click({
        try {
            netsh winsock reset | Out-Null
            $stUtil.Text = 'Winsock resetado. Reinicie o PC para concluir.'
        } catch { $stUtil.Text = "Falhou: $($_.Exception.Message)" }
    }.GetNewClosure())

    # --- 3) Trocar DNS do adaptador ativo ---
    $lblDns = New-Object Windows.Forms.Label
    $lblDns.Text = 'Trocar DNS do adaptador ativo:'
    $lblDns.SetBounds(15, 190, 400, 22)
    $page.Controls.Add($lblDns)

    $stDns = New-Object Windows.Forms.Label
    $stDns.SetBounds(15, 258, 400, 55)
    $stDns.ForeColor = [Drawing.Color]::DimGray
    $page.Controls.Add($stDns)

    # Retorna o adaptador conectado principal, ou $null.
    $pegarAdaptador = {
        Get-NetAdapter -Physical -ErrorAction Stop |
            Where-Object { $_.Status -eq 'Up' } |
            Sort-Object -Property ifIndex |
            Select-Object -First 1
    }

    $aplicarDns = {
        param($servidores, $nome)
        try {
            $ad = & $pegarAdaptador
            if (-not $ad) { $stDns.Text = 'Nenhum adaptador conectado (Up) encontrado.'; return }
            if ($null -eq $servidores) {
                Set-DnsClientServerAddress -InterfaceIndex $ad.ifIndex -ResetServerAddresses -ErrorAction Stop
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $ad.ifIndex -ServerAddresses $servidores -ErrorAction Stop
            }
            $stDns.Text = "$nome aplicado em '$($ad.Name)'."
        } catch { $stDns.Text = "Falhou: $($_.Exception.Message)" }
    }

    $btnCloudflare = New-Object Windows.Forms.Button
    $btnCloudflare.Text = 'Cloudflare (1.1.1.1)'
    $btnCloudflare.SetBounds(15, 218, 130, 32)
    $page.Controls.Add($btnCloudflare)
    $btnCloudflare.Add_Click({ & $aplicarDns @('1.1.1.1', '1.0.0.1') 'Cloudflare' }.GetNewClosure())

    $btnGoogle = New-Object Windows.Forms.Button
    $btnGoogle.Text = 'Google (8.8.8.8)'
    $btnGoogle.SetBounds(150, 218, 125, 32)
    $page.Controls.Add($btnGoogle)
    $btnGoogle.Add_Click({ & $aplicarDns @('8.8.8.8', '8.8.4.4') 'Google' }.GetNewClosure())

    $btnAuto = New-Object Windows.Forms.Button
    $btnAuto.Text = 'Automatico (DHCP)'
    $btnAuto.SetBounds(280, 218, 130, 32)
    $page.Controls.Add($btnAuto)
    $btnAuto.Add_Click({ & $aplicarDns $null 'DNS automatico (DHCP)' }.GetNewClosure())
}
