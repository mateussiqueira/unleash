# unleash

Ferramenta única para bypass/supressão de MDM no macOS. Funciona do Modo de Recuperação. Apple Silicon e Intel.

> Leia em: [English](README.md) | **Português**

## Instalação rápida

```bash
# Homebrew (mais fácil)
brew install mateussiqueira/unleash/unleash

# Download direto
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash-standalone.sh -o unleash
chmod +x unleash && sudo ./unleash
```

## Como usar

1. Copie a pasta `unleash` para um SSD externo (FAT32/APFS/exFAT)
2. Inicialize no Modo de Recuperação:
   - **Apple Silicon**: segure o botão de energia → Opções → Continuar
   - **Intel**: Cmd+R na inicialização
3. Abra o Terminal (Utilitários) e execute:

```bash
chmod +x "/Volumes/SeuSSD/unleash/unleash"
"/Volumes/SeuSSD/unleash/unleash"
```

Escolha "Full bypass" no menu. Ou use a linha de comando:

```bash
"/Volumes/SeuSSD/unleash/unleash" bypass
```

## Comandos principais

| Comando | Função |
|---------|--------|
| `bypass` | Bypass completo — cria admin + suprime MDM |
| `suppress` | Silencia o MDM sem criar usuário |
| `heal` | Verifica e reaplica supressão após updates |
| `persist` | Auto-heal em toda inicialização |
| `firewall` | Bloqueia IPs da Apple via pf (kernel) |
| `whitelist` | Bloqueia só MDM, mantém iCloud |
| `harden` | Mata processos MDM + remove perfis |
| `audit` | Varredura profunda + score de risco |
| `check` | Relatório pré-formatação |
| `monitor` | Vigia MDM a cada 5min |
| `doctor` | Diagnóstico pré-vôo completo |
| `report` | Status completo do sistema |
| `demo` | Simulação sem alterar nada |
| `vpn-kill` | Bloqueia MDM fora da VPN |
| `update` | Auto-update do GitHub |
| `uninstall` | Remove todos os vestígios |
| `test` | Simulação (dry-run) |

## Aliases

`by` = bypass, `sv` = suppress, `fw` = firewall, `wl` = whitelist,
`st` = status, `mn` = monitor, `doc` = doctor, `up` = update

## Por que não usar só o bypass-mdm?

O projeto original cresceu para 5 scripts (v2, v3, express, dualboot.sh, verify.sh), cada um com opções diferentes. O Unleash substitui todos em um único comando.

## Como funciona

O MDM opera em 4 camadas. O Unleash ataca todas:

1. **Marcadores DEP** — remove arquivos `.cloudConfig*`, cria iscas
2. **Rede** — `/etc/hosts` bloqueia 13+ domínios Apple + servidor MDM da org
3. **Daemons** — desabilita `ManagedClient.enroll`, `activationd`, etc
4. **Usuário** — limpa `~/Library/Preferences/com.apple.mdm.*` de todos os usuários

Firewall pf (comandos `firewall`/`whitelist`) pega o que o `/etc/hosts` não consegue — especialmente DNS-over-HTTPS.

## Intel vs Apple Silicon

| | Intel T2 | Apple Silicon |
|---|---|---|
| Recuperação | Cmd+R | Segurar Power |
| Volume sistema | Gravável (SIP off) | SSV (só leitura) |
| FileVault | Suportado | Suportado |
| Migration Assistant | Menos risco | **Traz MDM de volta** |

## Migration Assistant

Se você migrar de um Intel para Apple Silicon, o MDM vai voltar após o reboot. O Migration Assistant copia artefatos de usuário que os scripts antigos não limpam. O Unleash limpa `/Users/*/Library` explicitamente.

Se ainda assim voltar, execute `sudo ./unleash harden` do sistema já iniciado.

## Troubleshooting

**MDM volta após reboot** — execute `unleash suppress` da Recuperação. Se persistir, são artefatos do Migration Assistant. Execute `unleash harden` após o login.

**profiles mostra matrícula** — cosmético. O SSV armazena estado de perfil em modo somente leitura. Verifique os marcadores DEP com `unleash status`.

**FileVault não desbloqueia** — você precisa da senha de um usuário ou da chave de recuperação.

**Update do macOS** — execute `unleash heal`. Se usou `persist` antes do update, ele faz isso automaticamente.

## Limitações

- O serial continua no Apple Business Manager. Só a organização pode remover.
- Um wipe completo limpa o volume de Dados — execute novamente da Recuperação.
- O bloqueio de hosts pode ser burlado por DNS cache ou DoH. Firewall pf resolve.

## Licença

MIT. Veja [LICENSE](LICENSE).
