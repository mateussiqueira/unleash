# unleash — Quick Reference

Keep this on your SSD alongside the script.

## First time

1. Boot to Recovery (Apple Silicon: hold Power, Intel: Cmd+R)
2. Open Terminal → `chmod +x "/Volumes/YourSSD/unleash/unleash"`
3. Run → `"/Volumes/YourSSD/unleash/unleash"`
4. Pick "Full bypass" from the menu

## Common scenarios

| Você quer... | Comando |
|---|---|
| Bypass completo (cria usuário admin) | `./unleash bypass` |
| Só silenciar o MDM (sem criar usuário) | `./unleash suppress` |
| Consertar depois de atualizar macOS | `sudo ./unleash heal` |
| Nunca mais pensar nisso | `sudo ./unleash persist` + `sudo ./unleash whitelist` |
| Saber se vai travar após formatar | `sudo ./unleash check` |
| Vigiar MDM em tempo real | `sudo ./unleash monitor` |
| Instalar monitor para sempre | `sudo ./unleash monitor-install` |
| Limpeza pós-bypass (já logado) | `sudo ./unleash harden` |
| Varredura completa | `sudo ./unleash audit` |
| Voltar ao normal | `./unleash restore` |

## Aliases

`by` = bypass, `sv` = suppress, `fw` = firewall, `wl` = whitelist,
`st` = status, `mn` = monitor, `mn-st` = monitor-status

## Avisos

- **Não** rode `profiles renew` — isso reativa o MDM
- **Não** use "Apagar Conteúdo e Ajustes" — isso limpa o bypass
- Após formatar (wipe), rode o bypass de novo do Recovery
- Migration Assistant traz o MDM de volta — sempre rode `suppress` depois
