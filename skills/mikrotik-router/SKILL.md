---
name: mikrotik-router
description: >-
  MikroTik RouterOS 7 expert pre sieťových administrátorov. Použi tento skill vždy keď
  používateľ zmieni MikroTik, RouterOS, RouterBOARD, /ip, /interface, /system, /routing,
  /queue, /tool, firewall rules, VPN (IKEv2, SSTP, IPsec, WireGuard, OVPN, L2TP, GRE, EoIP,
  IPIP), bridge, VLAN, CAPsMAN, RADIUS, NPS, policy routing, route marking, bandwidth management,
  alebo akýkoľvek RouterOS CLI príkaz. Trigger tiež pri slovách: winbox, webfig, mikrotik
  scripting, routerboard, CCR, RB, hAP, CRS, CHR konfigurácia, /ip/firewall, /ip/ipsec,
  /interface/wireguard, /routing/bgp, /routing/ospf. Scope: RouterOS 7.x only.
---

# MikroTik RouterOS 7 — Admin Skill

## KRITICKÉ: RouterOS NIE JE GNU/Linux

RouterOS beží na Linux kerneli ale **všetko nad kernelom je MikroTik proprietary `nova` systém**.

**Na RouterOS NEEXISTUJE:**
- Žiadny `/bin`, `/usr`, `/etc`, `/var` — žiadna FHS štruktúra
- Žiadny bash, sh, ash — žiadny Unix shell
- Žiadny `ls`, `cat`, `grep`, `ps`, `mount`, `ip`, `iptables`, `systemctl`
- Žiadny apt, pkg, opkg — balíčky sú `.npk` súbory inštalované cez upload + reboot
- Žiadny `/proc` alebo `/sys` prístupný z userspace

**Čo EXISTUJE:**
- RouterOS CLI — vlastný jazyk, nie shell. Prístup cez SSH, serial, WinBox, WebFig
- REST API na `/rest/` (HTTP, port 80 default) — hlavné programatické rozhranie
- RouterOS scripting (`.rsc` súbory) — vlastná syntax, nie bash
- WebFig (web UI) na porte 80, WinBox protokol na porte 8291

**Časté chyby agenta:**
- NEROBÍŠ `ssh admin@host 'ls /'` — otvára RouterOS CLI, nie shell
- NENAVRHUJEŠ `mount`, `fdisk` — použi `/disk` príkazy
- NEHĽADÁŠ config v `/etc/` — konfigurácia je v RouterOS databáze
- `ping` je `/tool/ping` alebo `/ping` v CLI

---

## CLI Syntax a Základy

RouterOS CLI používa path-based navigáciu, nie Unix pipy:

```routeros
# Navigácia
/ip/address/print
/interface/print
/system/resource/print

# Pridanie záznamu
/ip/address/add address=192.168.1.1/24 interface=ether1

# Modifikácia (podľa ID alebo find výrazu)
/ip/address/set [find interface=ether1] address=10.0.0.1/24

# Zmazanie
/ip/address/remove [find address="192.168.1.1/24"]

# Safe mode (auto-revert ak session padne)
Ctrl+X alebo F4
```

**Kľúčové rozdiely od shellu:**
- `=` priraďuje vlastnosti (bez medzier okolo)
- `[find ...]` je query výraz (ako WHERE)
- Stringy používajú `""` (len dvojité uvodzovky)
- Komentáre: `#`
- Premenné: `:local myVar "value"` a `$myVar`
- Žiadne pipy, žiadne presmerovanie, žiadny subshell

---

## Hierarchia Menu

### /interface — Sieťové Rozhrania

| Sub-path | Popis |
|----------|-------|
| `/interface` | Zoznam, enable/disable, monitor všetkých rozhraní |
| `/interface/list` | Interface list skupiny a členovia |
| `/interface/bridge` | L2 bridge so STP/RSTP/MSTP, VLAN filtering, DHCP snooping |
| `/interface/ethernet` | Fyzický ethernet, switch chip, PoE |
| `/interface/vlan` | 802.1Q VLAN sub-interfaces |
| `/interface/bonding` | Link aggregation (LACP, balance-rr, active-backup) |
| `/interface/wifi` | WiFi ROS7 s CAPsMAN (vyžaduje wifi-qcom package) |
| `/interface/wireless` | Legacy wireless (ROS6 kompatibilita) |
| `/interface/wireguard` | WireGuard VPN tunely a peers |
| `/interface/vxlan` | VXLAN tunely |
| `/interface/gre` | GRE / GRE6 tunely |
| `/interface/eoip` | EoIP tunely (MikroTik proprietary) |
| `/interface/ipip` | IP-in-IP tunely |
| `/interface/6to4` | IPv6 transition tunely |
| `/interface/l2tp-server` / `l2tp-client` | L2TP VPN |
| `/interface/pptp-server` / `pptp-client` | PPTP VPN |
| `/interface/sstp-server` / `sstp-client` | SSTP VPN |
| `/interface/ovpn-server` / `ovpn-client` | OpenVPN |
| `/interface/pppoe-server` / `pppoe-client` | PPPoE |
| `/interface/lte` | LTE/4G/5G modem rozhrania |
| `/interface/dot1x` | 802.1X port autentifikácia |
| `/interface/macsec` | MACsec (802.1AE) šifrovanie |

### /ip — IPv4 Konfigurácia

| Sub-path | Popis |
|----------|-------|
| `/ip/address` | IPv4 adresy na rozhraniach |
| `/ip/route` | Statické routes |
| `/ip/settings` | Kernel parametre (forwarding, ECMP hash, RP filter) |
| `/ip/firewall` | Filter, NAT, mangle, raw, address-list, connection tracking |
| `/ip/dns` | DNS klient/server, statické záznamy, cache, adlist (v7.15+) |
| `/ip/dhcp-server` | DHCP server, networks, leases, options, matchers |
| `/ip/dhcp-client` | DHCP klient |
| `/ip/dhcp-relay` | DHCP relay agent |
| `/ip/pool` | Address pools |
| `/ip/arp` | ARP tabuľka |
| `/ip/neighbor` | Neighbor discovery (MNDP/CDP/LLDP) |
| `/ip/ipsec` | IPsec VPN (peer, profile, proposal, policy, identity) |
| `/ip/service` | Remote access services (SSH:22, Winbox:8291, API:8728, API-SSL:8729) |
| `/ip/hotspot` | Captive portal |
| `/ip/cloud` | MikroTik DDNS |
| `/ip/vrf` | Virtual Routing and Forwarding |
| `/ip/traffic-flow` | NetFlow/IPFIX export |

### /ipv6 — IPv6 Konfigurácia

| Sub-path | Popis |
|----------|-------|
| `/ipv6/address` | IPv6 adresy |
| `/ipv6/route` | IPv6 statické routes |
| `/ipv6/firewall` | IPv6 filter, mangle, raw, address-list |
| `/ipv6/nd` | Neighbor Discovery / Router Advertisement |
| `/ipv6/dhcp-client` / `dhcp-server` / `dhcp-relay` | DHCPv6 |

### /routing — Dynamické Routing Protokoly

| Sub-path | Popis |
|----------|-------|
| `/routing/route` | Unified routing tabuľka (read-only, všetky address families) |
| `/routing/rule` | Policy routing pravidlá |
| `/routing/table` | Custom routing table definície |
| `/routing/bgp` | BGP (instance, connection, template, session, vpn, evpn) |
| `/routing/ospf` | OSPF v2+v3 (instance, area, interface-template) |
| `/routing/rip` | RIP (instance, interface-template, keys) |
| `/routing/filter` | Routing filtre (script-like syntax) |
| `/routing/bfd` | Bidirectional Forwarding Detection |

### /system — Správa Systému

| Sub-path | Popis |
|----------|-------|
| `/system/identity` | Router hostname |
| `/system/resource` | CPU, pamäť, storage, uptime, hardware info |
| `/system/routerboard` | Hardware info, firmware, boot settings |
| `/system/package` | Nainštalované balíčky, update |
| `/system/clock` | Dátum, čas, timezone |
| `/system/ntp` | NTP klient/server |
| `/system/scheduler` | Naplánované úlohy |
| `/system/script` | Používateľské skripty |
| `/system/logging` | Log pravidlá a akcie (memory, disk, remote, email) |
| `/system/health` | Hardware monitoring (napätie, teplota, ventilátory) |
| `/system/watchdog` | Auto-reboot pri hang |
| `/system/backup` | Binárny backup/restore, cloud backup |
| `/system/reset-configuration` | Factory reset |

### /queue — QoS / Bandwidth Management

| Sub-path | Popis |
|----------|-------|
| `/queue/simple` | Per-target bandwidth limity (najjednoduchší QoS) |
| `/queue/tree` | Hierarchické queues (vyžaduje mangle marks) |
| `/queue/type` | Queue disciplíny: PFIFO, BFIFO, SFQ, RED, PCQ, CoDel, FQ-CoDel, CAKE, HTB |

### /tool — Diagnostika a Utility

| Sub-path | Popis |
|----------|-------|
| `/tool/ping` | ICMP ping |
| `/tool/traceroute` | Trace route |
| `/tool/torch` | Real-time traffic monitor |
| `/tool/bandwidth-test` | Speed test na vzdialený MikroTik |
| `/tool/netwatch` | Host monitoring so skriptmi (ICMP, TCP, HTTP, DNS) |
| `/tool/fetch` | HTTP/FTP download/upload |
| `/tool/romon` | Remote management overlay network |

### Ostatné Hlavné Menu

| Menu | Popis |
|------|-------|
| `/ppp` | PPP secrets, profiles, aktívne sessions, AAA |
| `/certificate` | Certificate store, ACME/Let's Encrypt, SCEP, CRL |
| `/user` | Používateľské účty, skupiny, SSH kľúče, AAA |
| `/snmp` | SNMP service a communities |
| `/radius` | RADIUS klient (PPP, login, hotspot, wireless, DHCP, IPsec, dot1x) |
| `/mpls` | MPLS, LDP, traffic engineering |
| `/file` | Správa súborov na router storage |
| `/log` | Prehliadač systémového logu |
| `/disk` | Správa storage zariadení |

---

## Firewall — Pravidlá a Zoradenie

### ⚠️ PRAVIDLO č.1: Zoradenie je kritické

**Pravidlá sa vyhodnocujú v poradí. Prvá zhoda vyhráva (filter/NAT). PUT pridáva NA KONIEC.**

```routeros
# Správny postup pri pridávaní firewall pravidla:
# 1. Nájdi ID drop-all pravidla
/ip/firewall/filter/print where action=drop chain=input

# 2. Pridaj pravidlo PRED drop-all ( nahraď *XX správnym ID )
/ip/firewall/filter/add chain=input action=accept dst-port=22 protocol=tcp place-before=*XX comment="Allow SSH"

# 3. Overenie poradia
/ip/firewall/filter/print
```

### Filter Actions

| Action | Správanie |
|--------|-----------|
| `accept` | Prijmi paket, zastav spracovanie |
| `drop` | Ticho zahoď paket |
| `reject` | Zahoď + pošli ICMP error |
| `jump` | Skok do user-defined chain (`jump-target`) |
| `return` | Návrat z jump chain |
| `log` | Zaloguj a pokračuj na ďalšie pravidlo |
| `fasttrack-connection` | FastTrack pre spojenie (len IPv4) |
| `add-src-to-address-list` | Pridaj src do address listu |
| `add-dst-to-address-list` | Pridaj dst do address listu |

### Kľúčové Matcher Vlastnosti

| Vlastnosť | Typ | Popis |
|-----------|-----|-------|
| `chain` | string | `input`, `forward`, `output`, alebo user-defined |
| `src-address` | IP/mask alebo range | Zhoda zdrojovej adresy |
| `dst-address` | IP/mask alebo range | Zhoda cieľovej adresy |
| `protocol` | string | `tcp`, `udp`, `icmp`, atď. |
| `src-port` / `dst-port` | int range | Porty, vyžaduje protocol=tcp\|udp |
| `in-interface` / `out-interface` | string | Meno rozhrania |
| `in-interface-list` / `out-interface-list` | string | Meno interface listu |
| `connection-state` | string | `established`, `related`, `new`, `invalid` |
| `src-address-list` / `dst-address-list` | string | Match voči address listu |
| `connection-mark` | string | Match voči connection mark (mangle) |
| `routing-mark` | string | Match voči routing mark |

### NAT — Network Address Translation

```routeros
# Typické masquerade (srcnat) pre WAN
/ip/firewall/nat/add chain=srcnat action=masquerade out-interface=ether1-wan comment="WAN masquerade"

# Port forwarding (dstnat) — presmerovanie portu 8080 na 192.168.1.100:80
/ip/firewall/nat/add chain=dstnat protocol=tcp dst-port=8080 action=dst-nat \
  to-addresses=192.168.1.100 to-ports=80 comment="Port forward HTTP"
```

### Mangle — Packet Marking pre Policy Routing

```routeros
# Označenie packets pre konkrétnu WAN linku (policy routing)
/ip/firewall/mangle/add chain=prerouting src-address=192.168.10.0/24 \
  action=mark-routing new-routing-mark=WAN2 passthrough=yes comment="Route VLAN10 cez WAN2"
```

---

## VPN Prehľad

### IPsec

```routeros
# Zobrazenie IPsec stavu
/ip/ipsec/active-peers/print
/ip/ipsec/statistics/print
/ip/ipsec/installed-sa/print

# Typická konfigurácia IKEv2 road-warrior (server strana)
/ip/ipsec/mode-config/add name=RW-conf split-include=192.168.0.0/16 address-pool=ipsec-pool
/ip/ipsec/policy/group/add name=RW-group
/ip/ipsec/profile/add name=RW-profile dh-group=ecp256,modp2048 enc-algorithm=aes-256
/ip/ipsec/proposal/add name=RW-proposal enc-algorithms=aes-256-cbc,aes-256-gcm pfs-group=none
/ip/ipsec/peer/add name=RW-peer passive=yes send-initial-contact=no \
  profile=RW-profile exchange-mode=ike2
/ip/ipsec/identity/add peer=RW-peer auth-method=eap-mschapv2 \
  generate-policy=port-strict policy-template-group=RW-group mode-config=RW-conf
```

### WireGuard

```routeros
# Vytvorenie WireGuard rozhrania
/interface/wireguard/add name=wg0 listen-port=51820

# Pridanie peer
/interface/wireguard/peers/add interface=wg0 public-key="PEER_PUBLIC_KEY" \
  allowed-address=10.10.10.2/32 endpoint-address=PEER_IP endpoint-port=51820

# Zobrazenie kľúčov
/interface/wireguard/print
```

### SSTP

```routeros
# SSTP server
/interface/sstp-server/server/set enabled=yes certificate=server-cert default-profile=default

# SSTP klient
/interface/sstp-client/add name=sstp-client1 connect-to=SERVER_IP user=USERNAME \
  password=PASSWORD certificate=client-cert
```

### L2TP/IPsec

```routeros
# L2TP server s IPsec
/interface/l2tp-server/server/set enabled=yes use-ipsec=required ipsec-secret=SECRET

# PPP profil pre L2TP klientov
/ppp/profile/add name=l2tp-profile local-address=10.0.0.1 remote-address=vpn-pool \
  dns-server=8.8.8.8
```

---

## Policy Routing a Route Marking

```routeros
# 1. Vytvorenie routing tabuliek
/routing/table/add name=WAN1 fib
/routing/table/add name=WAN2 fib

# 2. Default routes v každej tabuľke
/ip/route/add gateway=1.2.3.1 routing-table=WAN1 comment="WAN1 default"
/ip/route/add gateway=5.6.7.1 routing-table=WAN2 comment="WAN2 default"

# 3. Mangle — označenie paketov (prerouting a output chains)
/ip/firewall/mangle/add chain=prerouting src-address=192.168.10.0/24 \
  action=mark-routing new-routing-mark=WAN1 passthrough=yes
/ip/firewall/mangle/add chain=output routing-mark=WAN1 \
  action=mark-routing new-routing-mark=WAN1 passthrough=yes

# 4. Routing rules
/routing/rule/add src-address=192.168.10.0/24 table=WAN1
```

---

## Bridge a VLAN

```routeros
# Vytvorenie bridge s VLAN filtering
/interface/bridge/add name=br1 vlan-filtering=yes comment="Main bridge"

# Pridanie portov
/interface/bridge/port/add bridge=br1 interface=ether2 pvid=10
/interface/bridge/port/add bridge=br1 interface=ether3 pvid=20

# VLAN tabuľka
/interface/bridge/vlan/add bridge=br1 vlan-ids=10 tagged=br1,sfp1 untagged=ether2
/interface/bridge/vlan/add bridge=br1 vlan-ids=20 tagged=br1,sfp1 untagged=ether3

# IP adresa na bridge VLAN interface
/interface/vlan/add name=vlan10 vlan-id=10 interface=br1
/ip/address/add address=192.168.10.1/24 interface=vlan10
```

---

## REST API

HTTP verby sa mapujú inak ako v štandardných REST API:

| HTTP | RouterOS Akcia | CLI ekvivalent |
|------|----------------|----------------|
| `GET` | print (čítanie) | `/path/print` |
| `PUT` | **add (vytvorenie)** | `/path/add` |
| `PATCH` | set (úprava) | `/path/set` |
| `DELETE` | remove | `/path/remove` |
| `POST` | command (príkaz) | `/path/command` |

**Kľúčové gotchas:**
- `PUT` vytvára (NIE aktualizuje) — opak väčšiny REST API
- Empty password auth: `admin:` (dvojbodka povinná)
- `.id` pole je `*HEX` formát (napr. `*1`, `*A`)
- WebFig root (`GET /`) vracia HTTP 200 bez auth — použiť ako health check
- REST API (`/rest/`) vyžaduje auth (HTTP 401 bez neho)

```bash
# Príklady REST API volaní
curl -u admin: http://HOST/rest/ip/address
curl -u admin: -X PUT http://HOST/rest/ip/address \
  -H "content-type: application/json" \
  -d '{"address":"192.168.1.1/24","interface":"ether1"}'
curl -u admin: -X PATCH http://HOST/rest/ip/address/*1 \
  -H "content-type: application/json" \
  -d '{"disabled":"true"}'
curl -u admin: -X DELETE http://HOST/rest/ip/address/*1
```

---

## Scripting — Rýchly Prehľad

```routeros
# Premenné
:local myVar "hello"
:global myGlobal 42

# Podmienky
:if ($x > 10) do={
  :put "velke"
} else={
  :put "male"
}

# Slučky
:for i from=1 to=10 do={ :put $i }
:foreach item in=$myArray do={ :put $item }

# Práca s konfiguráciou
:local newId [/ip/address/add address=10.0.0.1/24 interface=ether1]
:local entries [/ip/address/find where interface=ether1]
:local addr [/ip/address/get $newId address]

# Error handling
:do {
  /ip/address/add address=invalid interface=ether1
} on-error={
  :log error "Zlyhalo pridanie adresy"
}

# Scheduler (cron ekvivalent)
/system/scheduler/add name=my-task interval=1h \
  on-event="/system/script/run myScript"

# Logovanie
:log info "Router reštartovaný"
:log warning "Vysoká záťaž CPU"
:log error "Chyba VPN spojenia"
```

### Dátové typy

| Typ | Syntax | Príklad |
|-----|--------|---------|
| String | `"text"` | `"hello world"` |
| Number | `123` | `42`, `0xFF` |
| Boolean | `true` / `false` | `true`, `yes`, `no` |
| IP Address | `1.2.3.4` | `192.168.1.1` |
| IP Prefix | `1.2.3.0/24` | `10.0.0.0/8` |
| Array | `{1; 2; 3}` | `{"a"; "b"}` |
| Time | `1h2m3s` | `30s`, `5m`, `1d` |

---

## Diagnostika a Troubleshooting

```routeros
# Systémové info
/system/resource/print
/system/routerboard/print
/system/health/print

# Sledovanie logov v reálnom čase
/log/print follow

# Sieťová diagnostika
/tool/ping address=8.8.8.8 count=4
/tool/traceroute address=8.8.8.8
/tool/torch interface=ether1

# Firewall a NAT štatistiky
/ip/firewall/filter/print stats
/ip/firewall/nat/print stats

# IPsec debug
/ip/ipsec/active-peers/print
/ip/ipsec/installed-sa/print detail
/ip/ipsec/statistics/print

# Interface monitoring
/interface/print stats
/interface/monitor-traffic [find]

# Routing tabuľka
/routing/route/print where active=yes
/ip/route/print

# ARP tabuľka
/ip/arp/print

# DHCP leases
/ip/dhcp-server/lease/print
```

---

## Hardware — Architektúry

| MikroTik názov | CPU | Bežný HW |
|----------------|-----|----------|
| `x86` | x86_64 | CHR, x86 RouterBOARDs |
| `arm64` | aarch64 | Moderné ARM dosky (RB5009, Chateau, CCR2xxx) |
| `arm` | ARMv7 | Staršie ARM dosky |
| `mipsbe` | MIPS big-endian | Legacy RouterBOARDs |
| `mmips` | MIPS multi-core | hAP ac, RB4011 |
| `smips` | MIPS single-core | hAP lite, mAP |
| `ppc` | PowerPC | CCR1xxx séria |
| `tile` | Tilera | CCR staršie modely |

---

## Default Credentials a Prvé Prihlásenie

- Username: `admin`
- Password: (prázdne — bez hesla)
- Pri prvom SSH/console prihlásení ROS7 vyzve na nastavenie hesla alebo stlač `a` na preskočenie

---

## Správa Inšpekcia z CLI

```routeros
# PCI zariadenia (ekvivalent lspci)
/system/resource/hardware/print

# IRQ pridelenia
/system/resource/irq/print

# Nainštalované balíčky
/system/package/print

# IP services a porty
/ip/service/print

# Sieťové rozhrania
/interface/print detail

# Certifikáty
/certificate/print detail

# Používatelia
/user/print
```

---

## Postup pri Konfigurácii

1. Identifikuj relevantné menu cesty
2. Použi `print` na zistenie aktuálneho stavu
3. Aplikuj zmeny (add/set/remove)
4. Over výsledok (`print`, diagnostické nástroje)
5. Pri firewall pravidlách vždy skontroluj poradie
6. Exportuj config pre zálohu: `/export file=backup-$(date)`

**Oficiálna dokumentácia:** `https://help.mikrotik.com/docs/spaces/ROS/`

Pri poskytovaní príkladov vždy použi ROS7 syntax (`/ip/firewall/filter`) a zahrni komentáre vysvetľujúce účel každého pravidla.