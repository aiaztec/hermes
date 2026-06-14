---
name: server-hardening
description: Komplexné zabezpečenie Linux servera (Debian) - UFW firewall hardening, ARP filtering, stealth režim, minimalizácia viditeľnosti na sieti
category: system-administration
---

# Server Hardening Skill

Tento skill poskytuje postupy pre komplexné zabezpečenie Linux servera (zamerané na Debian), vrátane firewallu (UFW), filtrovania ARP paketov pre "stealth" režim a minimalizácie viditeľnosti na sieti.

## Kedy použiť tento skill

- Používateľ žiada o "hardening servera", "zabezpečenie servera", "stealth režim"
- Potreba skryť server pred Nmap scanom (ARP level)
- Znefunkčnenie služieb, ktoré sprístupňujú server (ICMP, mDNS, UPnP, LLMNR)
- Zmena UFW politiky na DROP (tiché ignorovanie)
- Inštalácia a konfigurácia UFW/arptables

## Základné pravidlá pre agenta

1. **Plánovanie:** Ak používateľ napíše "naplanuj", "navrhni plán" alebo podobné, **Iba textový plán**, žiadne vykonávanie príkazov. Vykonávanie až po výslovnom súhlase ("y" alebo "potvrdzujem").
2. **Inštalácia:** Nikdy neinštaluj nič bez výslovného povolenia používateľa.
3. **Zmeny v systéme:** Pred akoukoľvek zmenou v súboroch alebo spustením príkazov vypíš zoznam príkazov a požiadaj o potvrdenie.
4. **Perzistentnosť:** Vždy použi `apt-mark manual` pre manuálne inštalované balíčky, aby ich `apt autoremove` neodstránil.
5. **Testovanie:** Po zmene politiky UFW na DROP over, či SSH stále funguje (používateľ má povolenú IP).

## Časť 1: UFW Firewall Hardening

### 1.1 Inštalácia a základná konfigurácia
```bash
# Kontrola stavu
sudo ufw status verbose

# Ak UFW chýba, inštalácia:
sudo apt update
sudo apt install -y ufw gufw
sudo apt-mark manual ufw gufw  # Dôležité!
sudo ufw enable
```

### 1.2 Záloha pred úpravami
```bash
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.backup.$(date +%Y%m%d)
sudo cp /etc/ufw/before6.rules /etc/ufw/before6.rules.backup.$(date +%Y%m%d)
sudo cp /etc/ufw/ufw.conf /etc/ufw/ufw.conf.backup.$(date +%Y%m%d)
```

### 1.3 Vypnutie služieb sprístupňujúcich server (ICMP, mDNS, UPnP)

#### a) ICMP (Ping) – IPv4 (`/etc/ufw/before.rules`)
Zakomentuj riadky pre ICMP:
```bash
sudo sed -i 's/^-A ufw-before-input -p icmp/# Disabled for security: &/' /etc/ufw/before.rules
sudo sed -i 's/^-A ufw-before-forward -p icmp/# Disabled for security: &/' /etc/ufw/before.rules
```

#### b) mDNS (port 5353) a UPnP (port 1900) – IPv4
```bash
sudo sed -i 's/^-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353/# Disabled for security: &/' /etc/ufw/before.rules
sudo sed -i 's/^-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900/# Disabled for security: &/' /etc/ufw/before.rules
```

#### c) IPv6 – `before6.rules`
```bash
sudo sed -i 's/^-A ufw6-before-input -p udp -d ff02::fb --dport 5353/# Disabled for security: &/' /etc/ufw/before6.rules
sudo sed -i 's/^-A ufw6-before-input -p udp -d ff02::f --dport 1900/# Disabled for security: &/' /etc/ufw/before6.rules
# DHCPv6 (port 546/547)
sudo sed -i 's/^-A ufw6-before-input -p udp -s fe80::\/10 --sport 547 -d fe80::\/10 --dport 546/# Disabled for security: &/' /etc/ufw/before6.rules
```

#### d) LLMNR (Link-Local Multicast Name Resolution)
```bash
grep -i "LLMNR" /etc/systemd/resolved.conf
# Ak nie je "LLMNR=no", uprav:
sudo sed -i 's/^#LLMNR=.*/LLMNR=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

### 1.4 Zmena predvolenej politiky na DROP (stealth)
```bash
# Pridaj riadok do /etc/ufw/ufw.conf (ak chýba)
echo 'DEFAULT_INPUT_POLICY="DROP"' | sudo tee -a /etc/ufw/ufw.conf
# Ak tam je REJECT, zmeň:
sudo sed -i 's/DEFAULT_INPUT_POLICY="REJECT"/DEFAULT_INPUT_POLICY="DROP"/' /etc/ufw/ufw.conf
```

### 1.5 Aplikácia zmien
```bash
sudo ufw reload
sudo ufw status verbose  # Očakávaný výstup: Default: deny (incoming)
```

### 1.6 Overenie
```bash
sudo iptables -L ufw-skip-to-policy-input -n -v  # target DROP
sudo iptables -L ufw-before-input -n -v | grep icmp || echo "ICMP je blokované"
```

## Časť 2: ARP Filtering (Stealth na Layer 2)

Táto časť rieši skrytie servera pred ARP scanom (napr. `nmap -sn`), ktorý vidí MAC adresu aj keď je ICMP blokované.

### 2.1 Kedy použiť ARP filtering
- Server je viditeľný cez `nmap` (ukazuje MAC adresu) napriek UFW hardeningom.
- Chceme, aby server neodpovedal na ARP žiadosti od neoprávnených zariadení.

### 2.2 Inštalácia arptables
```bash
sudo apt update
sudo apt install -y arptables
```

### 2.3 Politika pre "Variant 2" (odporúčané pre servery, ktoré potrebujú komunikovať s inými PC)
- **INPUT (prichádzajúce ARP): DROP** – server neodpovie na ARP žiadosti (okrem povolených).
- **OUTPUT (odchádzajúce ARP): ACCEPT** – server môže sám hľadať iné zariadenia (neodstrihne sa od siete).
- **Povolené IP:** Tvoja IP (192.168.22.39) a brána (gateway).

```bash
# Vyčistenie pravidiel
sudo arptables -F

# Predvolené politiky
sudo arptables -P INPUT DROP
sudo arptables -P OUTPUT ACCEPT
sudo arptables -P FORWARD DROP

# Zistenie brány
GATEWAY_IP=$(ip route show default | awk '/default/ {print $3}')
echo "Brána: $GATEWAY_IP"

# Povolenie ARP pre tvoju IP
sudo arptables -A INPUT -s 192.168.22.39 -j ACCEPT

# Povolenie ARP pre bránu (aby server mohol komunikovať von)
sudo arptables -A INPUT -s $GATEWAY_IP -j ACCEPT
```

### 2.4 Uloženie pravidiel (perzistentnosť)
```bash
# Vytvorenie adresára
sudo mkdir -p /etc/arptables

# Uloženie pravidiel
sudo arptables-save > /etc/arptables/rules.rules

# Nastavenie načítania po reštarte (cez rc.local)
if [ ! -f /etc/rc.local ]; then
    echo '#!/bin/bash' | sudo tee /etc/rc.local
    sudo chmod +x /etc/rc.local
fi
echo "arptables-restore < /etc/arptables/rules.rules" | sudo tee -a /etc/rc.local
```

### 2.5 Overenie ARP pravidiel
```bash
sudo arptables -L -v
# Test zo vzdialeného zariadenia: nmap -sn <IP_SERVERA> by mal ukázať "Note: Host seems down"
```

### 2.6 Dôsledky pre komunikáciu
| Komunikácia | Stav po aplikovaní |
| :--- | :--- |
| Tvoje SSH z 192.168.22.39 | ✅ Funguje (ARP povolené) |
| Server → Internet (cez bránu) | ✅ Funguje (ARP brány povolené) |
| Server → Iný PC v sieti | ✅ Funguje (OUTPUT ACCEPT) |
| Iný PC → Server (ping, Nmap) | ❌ Nefunguje (INPUT DROP) |
| Nmap ARP scan | ❌ Server neviditeľný ("Host seems down") |

## Časť 3: Ďalšie odporúčania (Intrusion Check)

Pre komplexné zabezpečenie odporúčame spustiť skript `intrusion-check.sh` (súčasť skilu `system-administration`):
- Kontrola otvorených portov
- Kontrola SSH konfigurácie (povolenie len pre tvoju IP)
- Kontrola aktualizácií systému
- Kontrola running services

## Dôležité upozornenia (Pitfalls)

1. **UFW môže zmiznúť po `apt upgrade`/`apt autoremove`:**
   - Riešenie: `sudo apt-mark manual ufw gufw` po inštalácii.
2. **ARP filtering a komunikácia:**
   - Variant 2 (INPUT DROP, OUTPUT ACCEPT) je kompromis: server nevidno, ale môže iniciovať spojenia.
   - Ak potrebuješ úplný stealth aj pre odchádzajúce ARP, použi Variant 1 (vstup aj výstup DROP) – ale server stratí schopnosť hľadať iné zariadenia v sieti.
3. **Testovanie SSH:**
   - Pred zmenou UFW politiky na DROP sa uisti, že SSH pravidlo pre tvoju IP je aktívne.
4. **MAC adresy:**
   - MAC adresa servera (napr. Proxmox VM) je viditeľná na Layer 2 iba v rámci toho istého broadcast domény (VLAN/subnet). Toto je fyzikálne obmedzenie, ARP filtering ho rieši na úrovni odpovedí.

## Overenie funkčnosti (Verification)

- `sudo ufw status verbose` → `Status: active`, `Default: deny (incoming)`
- `sudo iptables -L ufw-skip-to-policy-input -n -v` → target DROP
- `sudo arptables -L -v` → INPUT policy DROP, povolené len tvoja IP a brána
- Test Nmap zo vzdialeného zariadenia: `nmap -sn <IP>` → "Host seems down"
- Test ping: `ping <IP>` → 100% packet loss, žiadna ICMP odpoveď

## Príklad použitia

**Používateľ:** "naplanuj kompletné zabezpečenie servera, chcem ho celkom skryť na sieti"

**Agent (podľa tohto skilu):**
1. Vypíše zoznam krokov (Časť 1 a Časť 2) bez vykonávania.
2. Po súhlase ("y") postupuje podľa krokov.
3. Po dokončení overí stav a informuje používateľa o dosiahnutom stealth režime.

## Zdieľanie skilu

Tento skill je uložený v zdieľanom repozitári `~/repos/aiaztec-hermes/skills/server-hardening/`.
Symlink do lokálneho `~/.hermes/skills/` je vytvorený automaticky.

---

*Skill vytvorený na základe skúseností z 8. mája 2026 (Debian 13, UFW, arptables).*
