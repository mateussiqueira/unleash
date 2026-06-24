---
layout: default
title: Referência de Comandos — unleash
---

# Referência de Comandos

## Bypass & Suppress

| Comando | Descrição | Recovery | Iniciado |
|---------|-----------|----------|----------|
| `bypass` | Bypass completo: cria usuário admin + suprime MDM | ✓ | ✗ |
| `suppress` | Suprime registro sem criar um usuário | ✓ | ✓ |
| `heal` | Reaplica supressão após atualizações do macOS | ✓ | ✓ |
| `persist` | Instala LaunchDaemon para auto-recuperação na inicialização | ✓ | ✓ |
| `unpersist` | Remove o LaunchDaemon de auto-recuperação | ✗ | ✓ |

### `bypass`
Cria uma conta admin temporária e suprime todas as 5 camadas do MDM.
**Deve executar do Recovery.**
```bash
./unleash bypass
```

### `suppress`
Silencia o registro MDM sem criar um novo usuário.
Funciona tanto do Recovery quanto do sistema já iniciado.
```bash
sudo ./unleash suppress
```

### `heal`
Reaplica a supressão após atualizações do macOS reativarem os daemons de registro.
Em sistemas já iniciados, precisa de sudo. Com `persist`, executa automaticamente em cada inicialização.
```bash
sudo ./unleash heal
```

### `persist`
Instala um LaunchDaemon que executa `heal` automaticamente em cada inicialização.
Sobrevive a atualizações do macOS.
```bash
sudo ./unleash persist
```

### `unpersist`
Remove o LaunchDaemon de persistência.
```bash
sudo ./unleash unpersist
```

---

## Firewall & Rede

| Comando | Descrição | Privilégio |
|---------|-----------|------------|
| `firewall` | Bloqueia faixas de IP Apple MDM via pf | sudo |
| `firewall-off` | Remove o bloqueio pf do MDM | sudo |
| `whitelist` | Bloqueia apenas domínios MDM, mantém iCloud/App Store | sudo |

### `firewall`
Filtragem de pacotes a nível de kernel. Bloqueia toda a faixa de IP da Apple (`17.0.0.0/8`).
À prova de DoH — não pode ser contornado por DNS-over-HTTPS.
**Aviso:** Quebra iCloud, App Store e atualizações do sistema.
```bash
sudo ./unleash firewall
```

### `firewall-off`
Remove as regras pf adicionadas por `firewall`.
```bash
sudo ./unleash firewall-off
```

### `whitelist`
Resolve apenas domínios MDM para IPs e bloqueia especificamente aqueles.
Mantém iCloud e App Store funcionando enquanto bloqueia o registro MDM.
```bash
sudo ./unleash whitelist
```

---

## Sistema em Execução

| Comando | Descrição | Privilégio |
|---------|-----------|------------|
| `harden` | Mata processos MDM + remove perfis + limpa DNS | sudo |
| `audit` | Varredura profunda do sistema com score de risco | sudo |

### `harden`
Mata processos MDM em execução, remove perfis de configuração e limpa o cache DNS.
Útil quando o MDM está registrando ativamente em um sistema já iniciado.
```bash
sudo ./unleash harden
```

### `audit`
Executa uma varredura MDM profunda:
- Verifica marcadores DEP
- Escaneia perfis de configuração
- Verifica launch agents e daemons
- Procura certificados MDM
- Gera um score de risco (0–100)
```bash
sudo ./unleash audit
```

---

## Monitoramento

| Comando | Descrição |
|---------|-----------|
| `check` | Relatório de segurança pré-formatação/pré-atualização |
| `monitor` | Inicia vigia MDM em segundo plano (intervalo de 5 min) |
| `monitor-install` | Instala o monitor como um LaunchDaemon |
| `monitor-uninstall` | Remove o LaunchDaemon do monitor |
| `monitor-stop` | Para o daemon do monitor |
| `monitor-status` | Verifica se o monitor está rodando |
| `history` | Mostra o log de eventos do monitor/heal |
| `history-clear` | Limpa o log de eventos |

### `check`
Retorna **SAFE TO FORMAT** (sem MDM) ou **MDM DETECTED** (vai travar após limpar).
Também verifica segurança para atualizações do macOS.
```bash
sudo ./unleash check
```

### `monitor`
Daemon em segundo plano que verifica o estado do MDM a cada 5 minutos.
Envia uma notificação do macOS se o MDM tentar re-registrar.
Suporta `--webhook` opcional para alertas no Discord.
```bash
sudo ./unleash monitor
sudo ./unleash monitor --webhook https://discord.com/api/webhooks/...
```

### `history`
Mostra o log de eventos de execuções anteriores do monitor e heal.
```bash
sudo ./unleash history
```

---

## Gerenciamento de Estado

| Comando | Descrição |
|---------|-----------|
| `backup` | Salva o estado atual (hosts, perfis, launchd, configurações) |
| `restore` | Restaura a partir de um backup anterior |
| `dualboot` | Mira uma instalação macOS externa |

### `backup`
Salva `/etc/hosts`, estado dos perfis MDM, overrides launchd desabilitados e config do Unleash.
```bash
sudo ./unleash backup
```

### `restore`
Reverte o sistema para um estado salvo anteriormente.
```bash
sudo ./unleash restore
```

### `dualboot`
Cria uma conta admin e aplica supressão em um volume externo/bootcamp.
```bash
sudo ./unleash dualboot
```

---

## Comandos Inteligentes (v2.0)

| Comando | Descrição |
|---------|-----------|
| `init` | Assistente de configuração interativo |
| `suggest` | Análise de risco e recomendações baseadas no sistema |
| `remediate` | Limpeza MDM por organização |
| `predict` | Consulta de número serial — prevê qual organização registrou este Mac |
| `telemetry` | Gerencia estatísticas de uso anônimas (opt-in) |

### `init`
Assistente interativo que executa a configuração completa:
firewall → monitor → persist → backup → audit.
```bash
sudo ./unleash init
```

### `suggest`
Analisa seu sistema e fornece recomendações baseadas em risco.
```bash
sudo ./unleash suggest
```

### `remediate`
Limpeza MDM por organização. Suporta: JAMF, Mosyle, Addigy, Kandji, VMware.
Detecta automaticamente a organização a partir do registro DEP.
```bash
sudo ./unleash remediate
```

### `predict`
Lê o prefixo do número serial e verifica contra prefixos conhecidos de organizações MDM.
Útil antes de comprar um Mac usado.
```bash
./unleash predict ABC12345678
```

### `telemetry`
Gerencia estatísticas anônimas de uso (opt-in, DESLIGADO por padrão).
```bash
./unleash telemetry on
./unleash telemetry off
./unleash telemetry status
```

---

## VPN Kill-Switch

| Comando | Descrição |
|---------|-----------|
| `vpn-kill` | Instala pf kill-switch — bloqueia MDM fora da VPN |
| `vpn-kill-remove` | Remove o VPN kill-switch |
| `vpn-kill-status` | Verifica o estado do VPN kill-switch |

Projetado para Macs fornecidos por organizações que precisam registrar mas só devem se comunicar enquanto na VPN.
Bloqueia IPs MDM quando o dispositivo NÃO está conectado ao túnel VPN.
```bash
sudo ./unleash vpn-kill
sudo ./unleash vpn-kill-status
sudo ./unleash vpn-kill-remove
```

---

## Gerenciamento

| Comando | Descrição |
|---------|-----------|
| `update` | Autoatualização a partir do último release do GitHub |
| `uninstall` | Remoção completa com confirmações de segurança |
| `reinstall` | Desinstalar + reinstalar (persist + whitelist + monitor) |
| `config` | Ver ou editar configurações persistentes |
| `report` | Relatório completo do sistema (markdown ou JSON) |
| `demo` | Fluxo de bypass simulado (sem alterações reais) |
| `version` | Mostra a versão |

### `update`
Baixa o último release do GitHub. Verifica a assinatura GPG.
```bash
sudo ./unleash update
```

### `uninstall`
Remove todos os vestígios do Unleash. Pede confirmação.
```bash
sudo ./unleash uninstall
```

### `reinstall`
Desinstala e então reaplica persist + whitelist + monitor.
```bash
sudo ./unleash reinstall
```

### `config`
Ver ou editar configurações persistentes em `~/.unleash.conf`.
```bash
./unleash config
./unleash config show
./unleash config set key value
```

### `report`
Gera um relatório completo de status. Suporta `--json` para saída legível por máquina.
```bash
sudo ./unleash report
sudo ./unleash report --json
```

### `demo`
Executa um fluxo de bypass simulado. Nenhuma alteração real é feita.
```bash
./unleash demo
```

---

## Bot do Discord

| Comando | Descrição |
|---------|-----------|
| `discord-bot` | Inicia o bot de alertas do Discord |
| `discord-bot-stop` | Para o bot do Discord |
| `discord-bot-status` | Verifica se o bot do Discord está rodando |

Envia DMs no Discord quando atividade MDM é detectada.
```bash
sudo ./unleash discord-bot <token> <userId>
sudo ./unleash discord-bot-status
sudo ./unleash discord-bot-stop
```

---

## Diagnósticos

| Comando | Descrição |
|---------|-----------|
| `doctor` | Diagnóstico pré-voo — root, Recovery, libs, disco, dependências |
| `status` | Status do registro MDM (Recovery apenas, use `-d` para profundo) |
| `test` | Simulação dry-run de qualquer comando |

### `doctor`
Verifica: privilégios root, detecção do modo Recovery, versão do bash,
disco/volume, bibliotecas necessárias e conectividade com a internet.
```bash
./unleash doctor
```

### `status`
Mostra estado dos marcadores DEP, arquivo hosts, overrides de daemon.
Só funciona do Recovery. Use `check` ou `audit` em sistemas já iniciados.
```bash
./unleash status
./unleash status -d
```

### `test`
Modo dry-run. Simula um comando sem fazer alterações reais.
```bash
./unleash test bypass
./unleash test all
```

---

## Aliases

```
by  = bypass         sv  = suppress        st  = status
ls  = status         fw  = firewall        fw-off = firewall-off
wl  = whitelist      mn  = monitor         mn-install = monitor-install
mn-uninstall = monitor-uninstall           mn-stop = monitor-stop
mn-st = monitor-status                     doc = doctor
up  = update         uni = uninstall       rei = reinstall
vk  = vpn-kill       vkr = vpn-kill-remove vks = vpn-kill-status
```

---

## Opções Globais

| Opção | Efeito |
|-------|--------|
| `--verbose` | Mostra mensagens de debug |
| `--dry-run` | Simula sem fazer alterações |
| `--log-file <caminho>` | Escreve logs em um arquivo (anexado) |
