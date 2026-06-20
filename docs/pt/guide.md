---
layout: default
title: Guia de Arquitetura — unleash
---

# Guia de Arquitetura

## As Cinco Camadas do MDM

O registro MDM da Apple funciona através de cinco mecanismos independentes. Bloquear apenas um ou dois é o motivo pelo qual ferramentas de bypass falham com o tempo. O Unleash aborda todos os cinco.

```
Camada 1: Marcadores DEP  ───  /var/db/ConfigurationProfiles/Settings/.cloudConfig*
Camada 2: Bloqueio hosts  ───  /etc/hosts → 0.0.0.0 deviceenrollment.apple.com
Camada 3: Daemons         ───  launchd desabilitado → ManagedClient.enroll, activationd
Camada 4: Dados usuário   ───  ~/Library/Preferences/com.apple.mdm.*
Camada 5: Firewall pf     ───  pf anchor com.unleash/mdm → bloqueio kernel
```

### Camada 1: Marcadores de Registro DEP

Quando uma organização atribui um dispositivo no Apple Business Manager (ABM), o macOS cria arquivos marcadores:

```
/private/var/db/ConfigurationProfiles/Settings/
  .cloudConfigHasActivationRecord   ← "este serial está no ABM"
  .cloudConfigRecordFound           ← "verificamos e o registro foi acionado"
  .cloudConfigTimerCheck            ← "verificar novamente mais tarde"
```

**Ataque**: Remove todos os marcadores `.cloudConfig*`. Cria arquivos falsos (`.cloudConfigRecordNotFound`, `.cloudConfigProfileInstalled`) que dizem ao macOS "nenhum registro necessário."

**Fraqueza**: O macOS pode recriá-los a partir de dados em cache se a camada de rede não também estiver bloqueada.

### Camada 2: Bloqueio de Rede

O cliente de registro contata servidores Apple para baixar o perfil MDM. Sem acesso à rede, não pode completar.

**Ataque**: Adiciona 13+ domínios Apple MDM ao `/etc/hosts` apontando para `0.0.0.0` e `::`:

```
0.0.0.0 deviceenrollment.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 iprofiles.apple.com
...
```

Também bloqueia o host MDM específico da sua organização (extraído do registro DEP durante o bypass).

**Fraqueza**: DNS-over-HTTPS contorna `/etc/hosts` completamente. Chrome, Firefox e alguns serviços do sistema usam DoH por padrão.

### Camada 3: Override de Daemons

O macOS registra quatro daemons de registro que executam na inicialização:

| Daemon | Caminho do sistema | Efeito quando desabilitado |
|--------|-------------------|----------------------------|
| `com.apple.ManagedClient.enroll` | `/System/Library/LaunchDaemons/` | Nunca executa registro |
| `com.apple.ManagedClient.cloudConfiguration` | `/System/Library/LaunchDaemons/` | Sem busca de config em nuvem |
| `com.apple.mdmclient.daemon.runatboot` | `/System/Library/LaunchDaemons/` | Cliente MDM permanece morto |
| `com.apple.activationd` | `/System/Library/LaunchDaemons/` | Ativação nunca inicia |

**Ataque**: Cria overrides launchd desabilitados em `/private/var/db/com.apple.xpc.launchd/disabled.plist`. Este é o mesmo mecanismo que o macOS usa internamente para `sudo launchctl disable`.

### Camada 4: Limpeza de Nível de Usuário

Diretórios home carregam artefatos MDM que reativam o registro após o login ou Migration Assistant:

```
~/Library/Preferences/com.apple.mdm.*
~/Library/Preferences/com.apple.ManagedClient.*
~/Library/Application Support/com.apple.ManagedClient*/
~/Library/Caches/com.apple.mdmclient
~/Library/LaunchAgents/com.apple.mdm.*
```

**Ataque**: Varre todos os diretórios home no volume de Dados. Remove todos os plists, caches e launch agents relacionados ao MDM.

**Por que isso importa**: O Migration Assistant copia TUDO acima. Esta é a razão #1 do MDM voltar após um bypass bem-sucedido — e a etapa que a maioria das outras ferramentas pula completamente.

### Camada 5: Firewall pf (Nível de Kernel)

`/etc/hosts` pode ser contornado por:
- DNS-over-HTTPS (DoH) no Chrome/Firefox
- Respostas DNS em cache
- Conexões IP diretas

pf (packet filter) opera na camada de rede do kernel, abaixo da resolução DNS. DoH não contorna pf.

**Comando `firewall`**: Bloqueia toda a faixa de IP da Apple:
```
17.0.0.0/8      ← Apple
17.128.0.0/10   ← Apple (estendido)
```

**Comando `whitelist`**: Resolve apenas domínios MDM → IPs e bloqueia especificamente aqueles. iCloud/App Store continuam funcionando.

**Comando `vpn-kill`**: Bloqueia IPs MDM quando o dispositivo NÃO está conectado à sua VPN.

## Arquitetura do Script

```
unleash/
├── unleash                   # Ponto de entrada principal
├── lib/
│   ├── colors.sh             # Logging, cores, prompts, show_cmd_help()
│   ├── detect.sh             # Detecção de Recovery, montagem de volume
│   ├── validate.sh           # Validação de usuário/senha
│   ├── dscl.sh               # Directory Services (CRUD de usuário)
│   ├── suppress.sh           # Remoção DEP, hosts, desabilitação de daemon
│   ├── backup.sh             # Backup e restore
│   ├── status.sh             # Verificação de saúde e auditoria
│   ├── heal.sh               # Auto-recuperação + LaunchDaemon persist
│   ├── firewall.sh           # Gerenciamento de regras pf
│   ├── harden.sh             # Hardening do sistema em execução
│   ├── whitelist.sh          # Bloqueio seletivo iCloud-safe
│   ├── check.sh              # Avaliação pré-formatação
│   ├── monitor.sh            # Vigia MDM em segundo plano
│   ├── config.sh             # Leitura/escrita de arquivo de config
│   ├── doctor.sh             # Diagnóstico pré-voo
│   ├── history.sh            # Leitura/limpeza de log de eventos
│   ├── selfupdate.sh         # Autoatualização verificada com GPG
│   ├── uninstall.sh          # Remoção completa
│   ├── report.sh             # Relatório completo do sistema
│   ├── ma_detect.sh          # Detecção de Migration Assistant
│   ├── demo.sh               # Bypass simulado (sem alterações)
│   ├── vpn.sh                # Regras pf de kill-switch VPN
│   ├── init.sh               # Assistente de configuração
│   ├── suggest.sh            # Recomendações baseadas em risco
│   ├── remediate.sh          # Limpeza por organização
│   ├── predict.sh            # Consulta de número serial
│   ├── telemetry.sh          # Estatísticas anônimas de uso
│   └── discord.sh            # Bot de alertas Discord
├── docs/                     # Site Jekyll (GitHub Pages)
├── tests/                    # Testes Bats (78 testes)
└── examples/                 # build-standalone.sh, auto-bypass-usb.sh, etc.
```

### Fluxo de Dispatch

1. `unleash` carrega todos os módulos `lib/*.sh`
2. `load_config()` lê `~/.unleash.conf` (se existir)
3. O argumento do comando é casado com o `case` dispatch no main
4. A função handler é chamada (ex.: `cmd_bypass`, `cmd_firewall`)
5. Cada handler chama funções lib que fazem o trabalho real

### Build Autocontido

`examples/build-standalone.sh` concatena todos os módulos lib + corpo do script principal em um único arquivo (`unleash-standalone.sh`, ~3200 linhas). Sem dependências externas — funciona em qualquer macOS com bash.

## Processo de Build

1. **Fonte**: Módulos `lib/*.sh` individuais + ponto de entrada `unleash`
2. **Teste**: 78 testes Bats cobrindo todos os módulos
3. **Build**: `bash examples/build-standalone.sh` → `unleash-standalone.sh`
4. **Assinar**: `scripts/sign-release.sh` → Assinatura GPG destacada
5. **Release**: Release GitHub com standalone + assinatura + checksums

## Design de Segurança

### Sem persistência root
O Unleash não instala backdoor, cria usuários ocultos ou modifica o volume do sistema. Todas as alterações são reversíveis.

### Releases assinados com GPG
Releases são assinados com chave GPG. O `selfupdate` verifica a assinatura antes de aplicar atualizações.

### Telemetria opt-in
Telemetria está DESLIGADA por padrão. Se ativada, envia apenas contagens anônimas (comando executado, versão do macOS, sucesso/falha) — sem números de série, IPs ou dados identificáveis.

### Sem dependência de internet
Comandos principais (`bypass`, `suppress`, `heal`) funcionam completamente offline. Apenas `update`, `firewall` (resolução DNS) e `discord-bot` precisam de rede.

---

[Voltar ao início](/) · [FAQ](faq)

{% include lang-toggle.html %}
