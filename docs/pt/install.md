---
layout: default
title: Instalação — unleash
---

# Instalação

## Homebrew (mais fácil)

```bash
brew tap mateussiqueira/unleash
brew install unleash
```

Ou em um passo:
```bash
brew install mateussiqueira/unleash/unleash
```

## Download direto

```bash
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash-standalone.sh -o unleash
chmod +x unleash
sudo ./unleash init
```

## De um pendrive USB (para o modo Recovery)

1. Formate um USB/SSD como **FAT32**, **APFS** ou **exFAT**
2. Copie a pasta `unleash` (ou apenas `unleash-standalone.sh`) para o drive
3. Inicialize no Recovery e execute de `/Volumes/SeuDrive/unleash`

## Via curl no Recovery (precisa de internet)

```bash
curl -L https://raw.githubusercontent.com/mateussiqueira/unleash/main/unleash -o /tmp/unleash
chmod +x /tmp/unleash && /tmp/unleash bypass
```

## Compilando a partir do código-fonte

```bash
git clone https://github.com/mateussiqueira/unleash.git
cd unleash
bash examples/build-standalone.sh
# Saída: unleash-standalone.sh (~3200 linhas)
```

## Verificando a instalação

```bash
./unleash version
# → unleash v2.0.0

./unleash doctor
# Executa diagnósticos pré-voo
```
