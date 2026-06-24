---
layout: default
title: Solução de Problemas — unleash
---

# Solução de Problemas

## Erros Comuns

### "Not a known DirStatus"
A detecção automática de volume falhou.
```
[ERR] Not a known DirStatus
```

**Solução:**
1. Execute `diskutil list` para encontrar seu volume de Dados
2. Monte: `diskutil mount /dev/diskXsY`
3. Execute o unleash novamente

---

### "Full bypass must run from Recovery mode"
```
[ERR] Full bypass must run from Recovery mode.
```

**Causa:** `bypass` cria usuários admin via dscl, que só funciona no Recovery.
**Solução:** Inicialize no Recovery e tente novamente. Ou use `suppress` de um sistema já iniciado.

---

### Erros "Needs sudo"

Vários comandos precisam de root:
```
[ERR] Firewall needs sudo: sudo ./unleash firewall
[ERR] Heal needs sudo: sudo ./unleash heal
[ERR] Hardening needs sudo: sudo ./unleash harden
[ERR] Audit needs sudo: sudo ./unleash audit
[ERR] Check needs sudo: sudo ./unleash check
```

**Solução:** Anteceda `sudo` ao comando.

---

### MDM volta após reiniciar

A causa mais comum são **artefatos de nível de usuário** trazidos pelo Migration Assistant.

**Solução do Recovery:**
```bash
sudo ./unleash suppress
```

**Solução do sistema já iniciado:**
```bash
sudo ./unleash harden
```

Se continuar voltando:
```bash
sudo ./unleash persist   # auto-recuperação em cada inicialização
sudo ./unleash monitor   # vigia re-registro
```

---

### Atualização do macOS reativou o MDM

Atualizações do sistema restauram os daemons de registro automaticamente.

**Solução:**
```bash
sudo ./unleash heal
```

Se você executou `persist` antes da atualização, isso acontece automaticamente na próxima inicialização.

---

### "Profiles status" ainda mostra registro

Isso é **cosmético**. O macOS armazena o estado dos perfis no SSV (Volume Selado do Sistema) somente leitura.

**Não confie** em `profiles status -v`.
**Confie** em `unleash status -d`.

---

### FileVault está ativado

O Unleash detecta FileVault e pede a chave de recuperação ou senha do volume.

**Solução:** Se o desbloqueio automático falhar, desbloqueie o volume manualmente no Utilitário de Disco primeiro:
1. Vá para o Utilitário de Disco no Recovery
2. Selecione o volume de Dados
3. Arquivo → Desbloquear → Digite a senha
4. Execute o unleash novamente

---

### iCloud para de funcionar após o bypass

O bloqueio básico de `/etc/hosts` inclui `albert.apple.com` (ativação do iCloud) e `gdmf.apple.com`.

**Solução:** Use `whitelist` em vez do bloqueio básico:
```bash
sudo ./unleash whitelist
```

Ou remova manualmente estas duas linhas de `/etc/hosts`:
```
0.0.0.0 albert.apple.com
0.0.0.0 gdmf.apple.com
```

---

### "Not a macOS Data volume"

```
[ERR] Not a macOS Data volume
```

**Causa:** O volume montado não tem a estrutura esperada.

**Solução:** Execute `diskutil list` para encontrar o volume de Dados correto (procure por "Data" no nome ou pelo código `69414d41-...`). Monte o correto e tente novamente.

---

### Monitor não inicia

**Verifique:**
1. Já está rodando? `sudo ./unleash monitor-status`
2. Permissões: precisa de root
3. Logs: `/var/log/unleash-monitor.log`

**Solução:**
```bash
sudo ./unleash monitor-stop
sudo ./unleash monitor
```

---

### Não consigo baixar arquivos no Recovery

O modo Recovery não tem internet por padrão.

**Solução:**
1. Use um pendrive USB com o unleash copiado
2. Ou conecte-se ao Wi-Fi no Recovery (menu superior direito → ícone Wi-Fi)

---

### Erro "Library not found" na inicialização

```
ERROR: Library not found: /path/to/lib/colors.sh
```

**Causa:** Executando o script `unleash` fonte de fora do diretório do repositório.

**Solução:**
- Use a versão standalone (`unleash-standalone.sh`)
- Ou execute da raiz do repositório onde o diretório `lib/` existe
- Ou instale via Homebrew

---

### Regras do firewall não estão sendo aplicadas

pf pode ter regras existentes que conflitam.

**Solução:**
```bash
sudo ./unleash firewall-off   # limpa regras existentes
sudo ./unleash firewall       # reaplica
```

---

### "Dispositivo ainda trava após restauração DFU"

Uma restauração DFU/IPSW completa não remove a atribuição ABM — o serial permanece no Apple Business Manager.

**Estratégia:**
1. Após restaurar, **não conecte ao Wi-Fi**
2. Inicialize no Recovery
3. Execute `unleash bypass` antes do dispositivo contatar a Apple
4. Execute `unleash persist` e `unleash whitelist`
5. Só então conecte-se à internet

O serial fica no ABM para sempre — mas se o dispositivo nunca conectar sem proteções, ele não vai re-registrar.

---

### Verificação de assinatura GPG falha na atualização

```
[ERR] GPG signature verification failed
```

**Solução:**
1. Certifique-se de ter `gpg` instalado
2. Importe a chave de assinatura: `gpg --keyserver keys.openpgp.org --recv-key <KEY_ID>`
3. Tente `sudo ./unleash update` novamente
4. Ou baixe manualmente de [GitHub Releases](https://github.com/mateussiqueira/unleash/releases)

---

### Instalação via Homebrew falha

```
Error: ... homebrew-core ...
```

**Solução:** Certifique-se de que o tap está atualizado:
```bash
brew untap mateussiqueira/unleash
brew tap mateussiqueira/unleash
brew install unleash
```

---

## Logging

Todos os comandos produzem logs estruturados:

```
[INF] Data volume: /Volumes/Macintosh HD - Data
[ OK] Admin 'apple' created (UID 501)
[WRN] DEP activation record present
[ERR] Firewall needs sudo: sudo ./unleash firewall
[STP] Locating Data volume by APFS role...
[DBG] Checking pfctl availability
```

**Formato do log:**

| Prefixo | Nível |
|---------|-------|
| `[INF]` | Info — operação normal |
| `[ OK]` | Sucesso — operação concluída |
| `[WRN]` | Aviso — problema não crítico |
| `[ERR]` | Erro — operação falhou |
| `[STP]` | Passo — ação atual |
| `[DBG]` | Debug — verbose apenas |

Use `--verbose` para mensagens de debug e `--log-file <caminho>` para salvar em um arquivo:
```bash
sudo ./unleash heal --verbose --log-file /tmp/unleash.log
```

---

## Comandos de Diagnóstico

Execute estes para coletar informações antes de buscar ajuda:

```bash
# Verificação rápida de saúde
sudo ./unleash doctor

# Auditoria completa do sistema
sudo ./unleash audit

# Gerar relatório
sudo ./unleash report

# Simular um bypass
sudo ./unleash demo
```

---

## Obtendo Ajuda

- [GitHub Issues](https://github.com/mateussiqueira/unleash/issues)
- [Discussões](https://github.com/mateussiqueira/unleash/discussions)
- [Política de Segurança](https://github.com/mateussiqueira/unleash/blob/main/SECURITY.md)
