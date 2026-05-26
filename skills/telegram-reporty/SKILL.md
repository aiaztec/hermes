---
name: telegram-reporty
description: Postup pre doručovanie systémových reportov ako príloh cez Telegram API (curl).
metadata:
  hermes:
    tags: [telegram, reporty]
---

# Telegram-Reporty

Tento skill definuje spôsob, akým doručovať systémové reporty (napr. Oracle databázové audity, logy) používateľovi na Telegram ako súbory (prílohy), nie ako textové správy, aby sa zabezpečilo správne formátovanie a prenos dát.

## Použitie

Nikdy neposielaj súbory (HTML, CSV, TXT reporty) priamo cez `send_message` s parametrom `MEDIA`, ak chceš, aby boli doručené ako skutočné prílohy.

### Správny postup (via CURL):

```bash
curl -s -X POST https://api.telegram.org/bot<TOKEN>/sendDocument \
  -F chat_id=<CHAT_ID> \
  -F document=@/cesta/k/suboru.html \
  -F caption="Názov reportu"
```

## Pitfalls
- `send_message` s `MEDIA:` často nefunguje pre súbory ako .html alebo .csv (Telegram ich neotvorí ako prílohu).
- Vždy over, či `chat_id` a `bot_token` sú správne nastavené.
- Pri HTML reportoch používaj inline CSS, aby boli prehľadné aj v náhľade.
- Ak je report príliš veľký, zváž jeho kompresiu (napr. .zip), ale pre bežné auditné logy postačuje HTML/TXT.
