<p align="center">
  <img src="../icon.svg" width="100" alt="unleash logo">
  <br>
  <strong>unleash</strong>
  <br>
  <em>Script único de bypass MDM para macOS</em>
</p>

<p align="center">
  <a href="#instalar">Instalar</a> ·
  <a href="#inicio-rapido">Início Rápido</a> ·
  <a href="#comandos">Comandos</a> ·
  <a href="guide">Guia de Arquitetura</a> ·
  <a href="faq">FAQ</a> ·
  <a href="#solucao-de-problemas">Solução de Problemas</a>
</p>

---

unleash substitui os cinco scripts originais do bypass-mdm em um único arquivo que lida com todas as camadas do registro MDM da Apple: marcadores DEP, bloqueio de rede, substituição de daemons, artefatos de nível de usuário e firewall a nível de kernel. Funciona no modo Recovery em Apple Silicon e Intel.

**O que torna o unleash diferente de outras ferramentas de bypass:**

- **Cobre todas as 5 camadas** — não apenas marcadores DEP ou arquivo hosts. Bloqueia todos os caminhos que o MDM usa para re-registrar.
- **Limpeza de artefatos de usuário** — o Migration Assistant copia caches MDM por usuário. O Unleash limpa todos os diretórios home.
- **Firewall pf a nível de kernel** — `/etc/hosts` é contornado por DNS-over-HTTPS. pf não.
- **Daemon de auto-recuperação** — sobrevive a atualizações do macOS. `persist` + `heal` pegam tudo que a atualização resetar.
- **39 comandos** — bypass, suppress, monitor, harden, audit, backup, predict, remediate e mais.
- **macOS 12–27** — testado em Intel T2, M1, M2, M3, M4, M5.

---

## Instalar

**Homebrew (mais fácil)**
```bash
brew install mateussiqueira/unleash/unleash
```

**Download direto**
```bash
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash-standalone.sh -o unleash
chmod +x unleash
```

**De um pendrive USB (para o modo Recovery)**
1. Formate um USB/SSD como FAT32, APFS ou exFAT
2. Copie a pasta `unleash` (ou apenas `unleash-standalone.sh`) para o drive
3. Inicialize no Recovery e execute de `/Volumes/SeuDrive/unleash`

---

## Início Rápido

### Modo Recovery (bypass padrão)

1. Inicialize no Recovery:
   - **Apple Silicon**: segure o botão power → Options → Continue
   - **Intel**: Cmd+R ao ligar

2. Abra o Terminal (Utilitários → Terminal)

3. Execute:
   ```bash
   "/Volumes/SeuDrive/unleash" bypass
   ```

4. Siga as instruções para criar um usuário admin temporário

5. Reinicie. O registro MDM será suprimido.

### Sistema já iniciado (já configurado)

Se você já tem um Mac que foi bypassado anteriormente e o MDM voltou após uma atualização:

```bash
sudo ./unleash heal
```

Ou para verificar o status atual:

```bash
sudo ./unleash status -d
```

### Configuração com um comando (Mac novo)

```bash
sudo ./unleash init
```

Assistente interativo que executa a configuração completa: firewall, monitor, persist, backup e audit.

---

## Comandos

### Bypass & suppress

| Comando | Descrição | Recovery | Iniciado |
|---------|-----------|----------|----------|
| `bypass` | Bypass completo: cria usuário admin + suprime MDM | ✓ | ✗ |
| `suppress` | Suprime registro sem criar um usuário | ✓ | ✓ |
| `heal` | Reaplica supressão após atualizações do macOS | ✓ | ✓ |
| `persist` | Instala LaunchDaemon para auto-recuperação na inicialização | ✓ | ✓ |
| `unpersist` | Remove o LaunchDaemon de auto-recuperação | ✗ | ✓ |

### Firewall & hardening

| Comando | Descrição |
|---------|-----------|
| `firewall` | Bloqueia IPs Apple MDM via pf (nível de kernel, à prova de DoH) |
| `firewall-off` | Remove o bloqueio pf do MDM |
| `whitelist` | Bloqueia apenas domínios MDM, mantém iCloud/App Store |
| `harden` | Mata processos MDM, remove perfis, limpa DNS — do sistema iniciado |

### Diagnósticos

| Comando | Descrição |
|---------|-----------|
| `audit` | Varredura MDM profunda — perfis, certificados, launch agents, score de risco |
| `check` | Avaliação pré-formatação — este Mac vai travar após limpar? |
| `history` | Mostra o log de eventos do monitor/heal |
| `history-clear` | Limpa o log de eventos |
| `doctor` | Diagnóstico pré-voo — root, Recovery, libs, disco, dependências |
| `status` | Status do registro MDM (use `-d` para modo profundo) |
| `report` | Relatório completo do sistema em formato legível ou JSON |

### Monitoramento

| Comando | Descrição |
|---------|-----------|
| `monitor` | Monitora o estado do MDM a cada 5 minutos, auto-recupera se necessário |
| `monitor-stop` | Para o monitor em segundo plano |
| `monitor-status` | Verifica se o monitor está rodando |
| `monitor-install` | Instala o monitor como um LaunchDaemon |

### Kill-switch VPN

| Comando | Descrição |
|---------|-----------|
| `vpn-kill` | Instala kill-switch pf — bloqueia MDM fora do túnel VPN |
| `vpn-kill-remove` | Remove o kill-switch VPN |
| `vpn-kill-status` | Verifica o estado do kill-switch VPN |

### Utilitários

| Comando | Descrição |
|---------|-----------|
| `update` | Autoatualização a partir do GitHub Releases (verificada com GPG) |
| `uninstall` | Remoção completa com confirmações de segurança |
| `reinstall` | Desinstalar + instalar (atualização atômica) |
| `config` | Ver/editar configurações persistentes em `~/.unleash.conf` |
| `backup` | Salva o estado atual para restaurar depois |
| `restore` | Restaura a partir de um backup anterior |
| `demo` | Fluxo de bypass simulado — sem alterações reais |
| `test` | Simulação dry-run de qualquer comando |
| `dualboot` | Mira um volume externo ou dual-boot |

### Comandos inteligentes (v2.0)

| Comando | Descrição |
|---------|-----------|
| `init` | Assistente de configuração interativo — firewall, monitor, persist, backup |
| `suggest` | Análise de risco e recomendações baseadas no sistema |
| `remediate` | Limpeza por organização (JAMF, Mosyle, Addigy, Kandji, VMware) |
| `predict` | Consulta de número serial — prevê qual organização registrou este Mac |
| `telemetry` | Gerencia estatísticas de uso anônimas (opt-in) |
| `discord-bot` | Inicia o bot de alertas do Discord |
| `discord-bot-stop` | Para o bot do Discord |
| `discord-bot-status` | Verifica se o bot do Discord está rodando |

### Aliases

Cada comando tem um alias curto:

```
by  = bypass       fw  = firewall      fw-off = firewall-off
sv  = suppress     mn  = monitor       doc   = doctor
st  = status       up  = update        uni   = uninstall
rei = reinstall    vk  = vpn-kill      vkr   = vpn-kill-remove
vks = vpn-kill-status                  wl    = whitelist
it  = init         su  = suggest       rm   = remediate
pr  = predict      tel = telemetry     db   = discord-bot
dbs = discord-bot-stop                 dbs2  = discord-bot-status
```

### Opções globais

| Opção | Efeito |
|-------|--------|
| `--verbose` | Mostra mensagens de debug |
| `--log-file <caminho>` | Escreve logs em um arquivo |

---

## Cenários

### Antes de comprar um Mac usado

```bash
./unleash predict ABC12345678    # verifica serial contra organizações conhecidas
./unleash check                  # este Mac é seguro para formatar?
```

`predict` consulta o serial contra prefixos conhecidos de organizações MDM. Se corresponder a JAMF, Mosyle ou outra, você sabe o que esperar antes de comprar.

### Recuperação após Migration Assistant

1. Instale o macOS em um Mac novo
2. O Migration Assistant copia seus dados antigos
3. O MDM aparece em minutos após o login

**Solução**: Inicialize no Recovery e execute `unleash suppress` (ou `bypass` se precisar de um novo admin). Remove os marcadores DEP, artefatos de usuário e preferências MDM que o MA transferiu.

### Atualização do macOS trouxe o MDM de volta

1. A atualização do sistema restaura os daemons de registro automaticamente
2. O bloqueio MDM em `/etc/hosts` geralmente é preservado

**Solução**: `sudo ./unleash heal` — re-desabilita daemons e verifica todas as camadas. Se você executou `persist` antes da atualização, isso acontece automaticamente na próxima inicialização.

### Configurando um Mac novo antes do primeiro boot

1. Inicialize no Recovery sem Wi-Fi
2. Execute `unleash init` — assistente interativo
3. Ele irá: suprimir MDM, instalar persist, instalar whitelist, executar audit
4. Reinicie, configure normalmente, o MDM nunca incomoda

---

## Como Funciona

O MDM (Mobile Device Management) opera em cinco camadas no macOS. O Unleash bloqueia todas elas:

**Camada 1: Marcadores DEP** → `/etc/hosts` → **Camada 2: Bloqueio de rede**

**Camada 3: Override de daemons** → launchd desabilitado → **Camada 4: Artefatos de usuário**

**Camada 5: Firewall pf** → nível de kernel, à prova de DoH

### Camada 1: Marcadores de registro DEP

Em `/var/db/ConfigurationProfiles/Settings/`, a Apple armazena arquivos `.cloudConfig*` que marcam o Mac como registrado no DEP. Removê-los é a abordagem padrão de bypass.

**O que o unleash faz**: Remove todos os marcadores `.cloudConfig*`, cria arquivos falsos que dizem ao macOS que o dispositivo nunca foi registrado e impede a recriação bloqueando também a camada de rede.

### Camada 2: Bloqueio de rede

O cliente de registro contata os servidores da Apple para baixar o perfil MDM. Sem acesso à rede, ele não pode completar o registro.

**O que o unleash faz**:
- **`/etc/hosts`** (básico): Bloqueia 13+ domínios Apple MDM incluindo `deviceenrollment.apple.com`, `mdmenrollment.apple.com`, `iprofiles.apple.com`. Entradas IPv4 (0.0.0.0) e IPv6 (::).
- **Firewall pf** (avançado): Filtragem de pacotes a nível de kernel que bloqueia faixas de IP Apple mesmo quando DoH é usado.

Domínios bloqueados:

| Domínio | Serviço |
|---------|---------|
| `iprofiles.apple.com` | Entrega de perfis |
| `deviceenrollment.apple.com` | Serviço DEP |
| `mdmenrollment.apple.com` | Registro MDM |
| `acmdm.apple.com` | Apple Configurator 2 MDM |
| `axm-adm-mdm.apple.com` | Registro ACM |
| `albert.apple.com` | Atribuição ABM |
| `gdmf.apple.com` | Framework MDM |
| `configuration.apple.com` | Serviço de configuração |
| `xp.apple.com` | Gerenciamento de dispositivos |
| `gs.apple.com` | Registro GSM |
| `tb.apple.com` | Trust de dispositivo |
| `vpp.itunes.apple.com` | Programa de compra em volume |

Mais o host MDM específico da sua organização, extraído do registro DEP.

### Camada 3: Override de daemons

O macOS registra quatro daemons de registro que executam na inicialização:

| Daemon | Propósito |
|--------|-----------|
| `com.apple.ManagedClient.enroll` | Registro principal |
| `com.apple.ManagedClient.cloudConfiguration` | Configuração em nuvem |
| `com.apple.mdmclient.daemon.runatboot` | Cliente MDM |
| `com.apple.activationd` | Ativação do dispositivo |

**O que o unleash faz**: Cria overrides launchd desabilitados para todos os quatro, impedindo que iniciem.

### Camada 4: Limpeza de artefatos de usuário

O Migration Assistant e caches de login deixam dados de registro MDM nos diretórios home:

```
~/Library/Preferences/com.apple.mdm.*
~/Library/Preferences/com.apple.ManagedClient.*
~/Library/Application Support/com.apple.ManagedClient*/
~/Library/Caches/com.apple.mdmclient
~/Library/LaunchAgents/com.apple.mdm.*
```

**O que o unleash faz**: Varre todos os diretórios home no volume de Dados e remove todos os preferences, caches e launch agents relacionados ao MDM.

### Camada 5: Firewall pf (opcional, avançado)

`/etc/hosts` pode ser contornado por DNS-over-HTTPS (DoH). O pf opera a nível de kernel — DoH não o contorna.

**Comando `firewall`**: Bloqueia toda a faixa de IP da Apple (`17.0.0.0/8` + `17.128.0.0/10`). 100% eficaz mas quebra iCloud, App Store e atualizações.

**Comando `whitelist`**: Resolve apenas os domínios MDM essenciais para IPs e bloqueia especificamente aqueles. Mantém iCloud e App Store funcionando.

---

## Intel vs Apple Silicon

| | Intel T2 | Apple Silicon |
|---|---|---|
| Recovery | Cmd+R ao ligar | Segurar botão power |
| Volume do sistema | Gravável com SIP desabilitado | Apenas leitura (SSV) |
| Desbloqueio FileVault | `diskutil apfs unlockVolume` | Igual, precisa de senha ou chave de recuperação |
| Daemons de registro | Menos | `activationd` + `cloudConfiguration` |
| Migration Assistant | Menos arriscado | **Carrega estado MDM** — sempre limpar depois |

No Apple Silicon, todas as escritas miram o volume de Dados. O volume do sistema nunca é modificado. Não precisa desabilitar SIP.

---

## Compatibilidade com versões do macOS

| Versão | Codinome | Status |
|--------|----------|--------|
| 12.x | Monterey | ✓ Testado |
| 13.x | Ventura | ✓ Testado |
| 14.x | Sonoma | ✓ Testado |
| 15.x | Sequoia | ✓ Testado |
| 26.x | Tahoe | ✓ Testado |
| 27.x | (atual) | ✓ Testado |

Deve funcionar em qualquer versão que use o mesmo mecanismo de registro MDM — que não mudou desde Monterey.

---

## Solução de Problemas

### MDM volta após reiniciar

A causa mais provável são artefatos de nível de usuário. Execute do Recovery:
```bash
sudo ./unleash suppress
```
Ou de um sistema já iniciado:
```bash
sudo ./unleash harden
```

### Erro "Not a known DirStatus"

O script detecta volumes automaticamente, mas se você tiver uma configuração não padrão:
1. Execute `diskutil list` para encontrar seu volume de Dados
2. Monte: `diskutil mount /dev/diskXsY`
3. Execute unleash novamente

### Perfis ainda mostram registro

Isso é cosmético. O macOS armazena estado de perfis no SSV (Volume Selado do Sistema). Verifique os marcadores DEP reais:
```bash
sudo ./unleash status -d
```

### FileVault está ativado

O Unleash detecta FileVault e pede a chave de recuperação ou senha do volume. Se o desbloqueio automático falhar, desbloqueie o volume manualmente no Utilitário de Disco primeiro.

### Atualização do macOS reativou o MDM

Execute `sudo ./unleash heal` após qualquer atualização do macOS. Se você usou `persist` antes da atualização, isso acontece automaticamente na próxima inicialização.

### Posso usar iCloud após o bypass?

Sim, mas:
- O bloqueio básico de `/etc/hosts` também bloqueia `albert.apple.com` (ativação do iCloud) e `gdmf.apple.com`
- Use o comando `whitelist` em vez de `firewall` para bloquear apenas domínios MDM e deixar iCloud/App Store funcionando
- Ou remova manualmente essas duas linhas de `/etc/hosts`

### Restauração DFU / IPSW (travamento total)

Se o MDM for inquebrável mesmo do Recovery, o dispositivo pode precisar de uma restauração completa de firmware. Isso se aplica apenas ao Apple Silicon.

Você precisa de um segundo Mac com Apple Configurator 2 (grátis), um cabo USB-C e o arquivo IPSW para seu modelo de Mac.

1. Abra o Apple Configurator 2 no Mac auxiliar
2. Conecte o Mac travado via USB-C enquanto segura o power
3. No Configurator: clique com direito no dispositivo DFU → Advanced → Restore
4. Escolha o arquivo IPSW, aguarde 10–30 minutos
5. Após restaurar, inicialize no Recovery sem Wi-Fi e execute `unleash bypass`

**Isso apaga todos os dados.** Arquivos IPSW em [ipsw.me](https://ipsw.me).

---

## Logging

Todos os comandos registram com timestamps e níveis:

```
[INF] Data volume: /Volumes/Macintosh HD - Data
[ OK] Admin 'apple' created (UID 501)
[WRN] DEP activation record present
[ERR] Firewall needs sudo: sudo ./unleash firewall
[STP] Locating Data volume by APFS role...
[DBG] Checking pfctl availability
```

Use `--verbose` para mensagens de debug e `--log-file <caminho>` para escrever tudo em um arquivo.

---

## Segurança

- **Sem escritas no SSV** — todas as alterações miram o volume de Dados
- **Reversível** — `backup` salva o estado, `restore` reverte
- **Sem apagar dados** — nunca executa `profiles renew` ou comandos de apagar
- **Idempotente** — executar múltiplas vezes é inofensivo
- **Pede confirmação** antes de ações destrutivas

---

## Links

- [Repositório GitHub](https://github.com/mateussiqueira/unleash)
- [README completo](https://github.com/mateussiqueira/unleash/blob/main/README.md)
- [Guia de Arquitetura](guide)
- [FAQ](faq)
- [Changelog](https://github.com/mateussiqueira/unleash/blob/main/CHANGELOG.md)
- [Contribuindo](https://github.com/mateussiqueira/unleash/blob/main/CONTRIBUTING.md)
- [Código de Conduta](https://github.com/mateussiqueira/unleash/blob/main/CODE_OF_CONDUCT.md)
- [Política de Segurança](https://github.com/mateussiqueira/unleash/blob/main/SECURITY.md)
- [Discussões](https://github.com/mateussiqueira/unleash/discussions)
- [Reportar Bug](https://github.com/mateussiqueira/unleash/issues/new?template=bug_report.md)
