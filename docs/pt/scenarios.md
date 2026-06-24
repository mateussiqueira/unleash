---
layout: default
title: Cenários — unleash
---

# Cenários

## Antes de comprar um Mac usado

Verifique o número serial antes de comprar:

```bash
./unleash predict ABC12345678    # verifica serial contra prefixos conhecidos
./unleash check                  # este Mac é seguro para limpar?
```

`predict` consulta o serial contra prefixos conhecidos de organizações MDM.
Se corresponder a JAMF, Mosyle ou outra organização, você sabe o que esperar antes de comprar.

---

## Recuperação após Migration Assistant

1. Instale o macOS em um Mac novo
2. O Migration Assistant copia seus dados antigos
3. O MDM aparece em minutos após o login

**Solução:** Inicialize no Recovery e execute:
```bash
./unleash suppress
```

Ou `bypass` se precisar de um novo usuário admin. Remove os marcadores DEP,
artefatos de nível de usuário e preferências MDM que o MA transferiu.
*Este é o caso #1 que a maioria das outras ferramentas não trata — o Unleash lida com ele.*

---

## Atualização do macOS trouxe o MDM de volta

1. A atualização do sistema restaura os daemons de registro automaticamente
2. O bloqueio MDM em `/etc/hosts` geralmente é preservado

**Solução:**
```bash
sudo ./unleash heal
```

Re-desabilita daemons e verifica todas as camadas. Se você executou `persist`
antes da atualização, isso acontece automaticamente na próxima inicialização.

---

## Comprou um Mac de escritório

1. O serial pode ainda estar no ABM da empresa
2. Mesmo após limpeza total, conectar ao Wi-Fi no Assistente de Configuração aciona o registro

**Estratégia:**
1. Inicialize no Recovery **sem conectar ao Wi-Fi**
2. Execute `unleash bypass` antes do dispositivo contatar a Apple
3. Execute `unleash persist` e `unleash whitelist` para mantê-lo limpo
4. Só então conecte-se à internet

O serial fica no ABM para sempre — mas enquanto o dispositivo nunca conectar
com todas as proteções removidas, ele não vai re-registrar.

---

## Mac usado que já tem um usuário logado

```bash
sudo ./unleash audit       # verifica o estado atual
sudo ./unleash harden      # mata processos MDM imediatamente
sudo ./unleash whitelist   # bloqueia MDM mantendo iCloud
sudo ./unleash persist     # sobrevive a atualizações futuras
```

---

## Configurando um Mac novo antes do primeiro boot

1. Inicialize no Recovery sem Wi-Fi
2. Execute `unleash init` — assistente interativo
3. Ele irá: suprimir MDM, instalar persist, instalar whitelist, executar audit
4. Reinicie, configure normalmente, o MDM nunca incomoda

---

## Mac fornecido pela organização (deve registrar apenas na VPN)

Algumas organizações exigem que o Mac registre, mas somente quando conectado à VPN corporativa.

```bash
sudo ./unleash vpn-kill
```

Isso instala um pf kill-switch que bloqueia tráfego MDM quando o dispositivo
NÃO está conectado ao túnel VPN. O MDM só pode se comunicar através
da conexão VPN criptografada.

---

## Após uma restauração completa DFU/IPSW

Uma restauração DFU apaga tudo mas não remove a atribuição ABM.

1. Restaure via Apple Configurator 2
2. **Não conecte ao Wi-Fi**
3. Inicialize no Recovery
4. Execute `unleash bypass`
5. Execute `unleash persist && unleash whitelist`
6. Reinicie e conecte-se à internet com segurança

---

## Implantação automatizada (admins de TI)

Para implantar em múltiplas máquinas:

```bash
# Bypass via script
./unleash suppress --log-file /var/log/unleash-deploy.log

# Com persist + monitor
sudo ./unleash persist
sudo ./unleash monitor

# Relatório de auditoria em JSON
sudo ./unleash report --json

# Alertas no Discord
sudo ./unleash discord-bot <token> <userId>
```
