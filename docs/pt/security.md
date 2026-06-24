---
layout: default
title: Segurança — unleash
---

# Segurança & Proteção

## Princípios de Design

### Sem persistência root
O Unleash não instala backdoor, cria usuários ocultos ou modifica o
volume do sistema. Todas as alterações miram o **volume de Dados**
apenas e são totalmente reversíveis.

### Releases assinados com GPG
Todo release é assinado com uma chave GPG. O comando `update` verifica
a assinatura antes de aplicar atualizações. Se a verificação falhar, a
atualização é **rejeitada**.

### Telemetria opt-in
A telemetria está **DESLIGADA por padrão**. Se ativada, envia apenas
contagens anônimas:
- Nome do comando executado
- Versão do macOS
- Status de sucesso/falha

Sem números de série, IPs ou informações pessoalmente identificáveis.

### Sem dependência de internet
Comandos principais (`bypass`, `suppress`, `heal`) funcionam completamente
offline. Apenas `update`, `firewall` (resolução DNS) e `discord-bot`
precisam de acesso à rede.

---

## Garantias de Segurança

- **Sem escritas no SSV** — todas as alterações miram o volume de Dados
- **Reversível** — `backup` salva o estado, `restore` reverte
- **Sem apagar dados** — nunca executa `profiles renew` ou comandos de apagar
- **Idempotente** — executar múltiplas vezes é inofensivo
- **Pede confirmação** antes de ações destrutivas

---

## Níveis de Risco

| Nível | Descrição | Comandos |
|-------|-----------|----------|
| Seguro | Somente leitura, sem alterações | `status`, `check`, `doctor`, `audit`, `predict`, `report` |
| Baixo | Escreve apenas no arquivo hosts | `suppress`, `heal` |
| Médio | Cria/modifica arquivos do sistema | `bypass`, `dualboot`, `persist`, `whitelist` |
| Alto | Firewall a nível de kernel | `firewall`, `vpn-kill` |
| Destrutivo | Remoção completa | `uninstall`, `reinstall` |

---

## Divulgação Responsável

Encontrou um problema de segurança?
Veja a [Política de Segurança](https://github.com/mateussiqueira/unleash/blob/main/SECURITY.md).
