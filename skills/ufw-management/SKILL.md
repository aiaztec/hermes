---
name: ufw-management
description: Správa a hardening UFW firewallu na Debiane (inštalácia, konfigurácia, zneviditeľnenie servera na sieti)
category: system-administration
---

# UFW Management Skill

Tento skill obsahuje postupy pre správu UFW (Uncomplicated Firewall) na Debian systémoch, zamerané na bezpečnosť a "stealth" režim servera.

## Kedy použiť tento skill

- Používateľ žiada o konfiguráciu UFW, zvýšenie bezpečnosti firewallu
- Potreba vypnúť odpoveď na ping (ICMP), zakázať mDNS, UPnP, LLMNR
- Inštalácia alebo reinštalácia UFW/GUFW
- Zmena predvolenej politiky z REJECT na DROP (server neodpovedá vôbec)
- Riešenie problému, keď UFW zmizne po `apt upgrade`/`apt autoremove`

## Základné pravidlá pre agenta

1. **Plánovanie:** Ak používateľ napíše "naplanuj", "navrhni plán" alebo podobné, **Iba textový plán**, žiadne vykonávanie príkazov. Vykonávanie až po výslovnom súhlase ("y" alebo "potvrdzujem").
2. **Inštalácia:** Nikdy neinštaluj nič bez výslovného povolenia používateľa.
3. **Zmeny v systéme:** Pred akoukoľvek zmenou v súboroch alebo spustením príkazov vypíš zoznam príkazov a požiadaj o potvrdenie.
4. **Perzistentnosť:** Vždy použi `apt-mark manual ufw gufw` po inštalácii, aby ich `apt autoremove` neodstránil.

## Postup: Inštalácia a základná konfigurácia

### 1. Kontrola a inštalácia
```bash
# Kontrola stavu
sudo ufw status verbose

# Ak UFW chýba (príkaz neexistuje), inštalácia:
sudo apt update
sudo apt install -y ufw gufw
sudo apt-mark manual ufw gufw  # Dôležité!
sudo ufw enable
```

### 2. Záloha pred úpravami
Vždy zálohuj konfiguračné súbory:
```bash
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.backup.$(date +%Y%m%d)
sudo cp /etc/ufw/before6.rules /etc/ufw/before6.rules.backup.$(date +%Y%m%d)
sudo cp /etc/ufw/ufw.conf /etc/ufw/ufw.conf.backup.$(date +%Y%m%d)
```

### 3. Hardening – vypnutie služieb, ktoré sprístupňujú server

#### a) ICMP (Ping) – IPv4 (`/etc/ufw/before.rules`)
Zakomentuj tieto riadky (pridaj `#` na začiatok):
```
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT
-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT
```
Rovnako pre FORWARD sekciu (ak existuje).

**Príkaz na zakomentovanie (použi sudo):**
```bash
sudo sed -i 's/^-A ufw-before-input -p icmp/# Disabled for security: &/' /etc/ufw/before.rules
sudo sed -i 's/^-A ufw-before-forward -p icmp/# Disabled for security: &/' /etc/ufw/before.rules
```

#### b) mDNS (port 5353) a UPnP (port 1900) – IPv4
Zakomentuj:
```
-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT
-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT
```
Príkazy:
```bash
sudo sed -i 's/^-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353/# Disabled for security: &/' /etc/ufw/before.rules
sudo sed -i 's/^-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900/# Disabled for security: &/' /etc/ufw/before.rules
```

#### c) IPv6 – `before6.rules`
Zakomentuj rovnaké služby pre IPv6:
```bash
sudo sed -i 's/^-A ufw6-before-input -p udp -d ff02::fb --dport 5353/# Disabled for security: &/' /etc/ufw/before6.rules
sudo sed -i 's/^-A ufw6-before-input -p udp -d ff02::f --dport 1900/# Disabled for security: &/' /etc/ufw/before6.rules
# DHCPv6 (port 546/547)
sudo sed -i 's/^-A ufw6-before-input -p udp -s fe80::\/10 --sport 547 -d fe80::\/10 --dport 546/# Disabled for security: &/' /etc/ufw/before6.rules
```

#### d) LLMNR (Link-Local Multicast Name Resolution)
LLMNR je často spravovaný cez `systemd-resolved`. Overíme a vypneme:
```bash
grep -i "LLMNR" /etc/systemd/resolved.conf
# Ak nie je "LLMNR=no", uprav: sudo sed -i 's/^#LLMNR=.*/LLMNR=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

### 4. Zmena predvolenej politiky na DROP (úplne stíšenie)

Štandardne UFW používa `reject`, čo posiela ICMP "port unreachable". Chceme `DROP` (tiché ignorovanie).

**Uprav `/etc/ufw/ufw.conf`:**
```bash
# Pridaj riadok (ak chýba) alebo uprav:
echo 'DEFAULT_INPUT_POLICY="DROP"' | sudo tee -a /etc/ufw/ufw.conf
# Alebo ak tam je REJECT, zmeň:
sudo sed -i 's/DEFAULT_INPUT_POLICY="REJECT"/DEFAULT_INPUT_POLICY="DROP"/' /etc/ufw/ufw.conf
```

**Poznámka:** Ak súbor neobsahuje politiku, UFW používa vlastné predvolené (reject). Explicitné pridanie do súboru zabezpečí perzistentnosť.

### 5. Aplikácia zmien
```bash
sudo ufw reload
sudo ufw status verbose
# Očakávaný výstup: Default: deny (incoming)
```

### 6. Overenie "stealth" režimu
```bash
# Over iptables reťazec (mal by byť DROP)
sudo iptables -L ufw-skip-to-policy-input -n -v

# Test ping (z ineho zariadenia) - mal by byť tichý (timeout)
# ping -c 2 <IP_SERVERA>
```

## Dôležité upozornenia (Pitfalls)

1. **UFW môže zmiznúť po `apt upgrade`/`apt autoremove`:**
   - Ak bol UFW nainštalovaný ako závislosť (automaticky), `apt autoremove` ho odstráni.
   - **Riešenie:** Vždy po inštalácii spusti `sudo apt-mark manual ufw gufw`.
   - V našom prípade: UFW bol nainštalovaný ako závislosť gufw (automaticky), preto ho autoremove odstránil.

2. **REJECT vs DROP:**
   - `REJECT` pošle ICMP "port unreachable" → útočník vie, že server existuje.
   - `DROP` ticho ignoruje pakety → server je neviditeľný (stealth).

3. **Zálohy:**
   - Pred akoukoľvek úpravou vždy zálohuj súbory. UFW konfiguráky sú v `/etc/ufw/`.

4. **Povolené pravidlá:**
   - Tento skill predpokladá, že používateľ má explicitné pravidlo pre SSH (napr. z IP 192.168.22.39).
   - Pravidlá `ALLOW` majú prednosť pred predvolenou politikou.

5. **Testovanie:**
   - Predtým než zmeníš politiku na DROP, uisti sa, že máš funkčné SSH pripojenie (alebo fyzický prístup).
   - Zmena na DROP môže oddialiť čas odozvy pri testovaní (timeout).

## Overenie funkčnosti (Verification)

- `sudo ufw status verbose` → `Status: active`, `Default: deny (incoming)`
- `sudo iptables -L ufw-skip-to-policy-input -n -v` → target DROP
- `ping` zvonku → 100% packet loss, žiadna ICMP odpoveď
- `sudo iptables -L ufw-before-input -n -v | grep icmp` → žiadne pravidlá (zakomentované)

## Príklad použitia

**Používateľ:** "naplanuj hardening UFW: vypni ping, mDNS, UPnP, nastav DROP politiku"

**Agent (podľa tohto skilu):**
1. Vypíše zoznam krokov (bez vykonávania).
2. Po súhlase ("y") postupuje podľa krokov 1-6 vyššie.
3. Po dokončení overí stav a informuje používateľa.

## Zdieľanie skilu

Tento skill je uložený v zdieľanom repozitári `~/repos/aiaztec-hermes/skills/ufw-management/`.
Symlink do lokálneho `~/.hermes/skills/` je vytvorený automaticky.

---

*Skill vytvorený na základe skúseností z 8. mája 2026 (Debian 13, UFW 0.36.2-9).*
