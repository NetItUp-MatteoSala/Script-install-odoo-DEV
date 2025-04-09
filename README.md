# 🛠️ Script di Installazione per Odoo Community Edition AMBIENTE DEV

Questo script automatizza l'installazione di **Odoo Community Edition** (versione 18.0) in un ambiente di sviluppo su **Ubuntu**. È pensato per facilitare la creazione di un ambiente completo e funzionante con PostgreSQL, Python, VirtualEnv, Node.js, wkhtmltopdf, rtlcss e moduli OCA.

---

### ⚙️ Funzionalità

- Verifica della compatibilità con Ubuntu e Python 3.10+
- Installazione e configurazione di:
  - **PostgreSQL** e utenti (`odoo`, `NIU` o `CSG`)
  - Dipendenze di sistema e librerie di sviluppo
  - **wkhtmltopdf** e font necessari per i report PDF
  - **Node.js**, **npm** e **rtlcss** per il supporto LTR
  - Ambiente **Python Virtualenv** dedicato
- Clonazione automatica delle repository:
  - `odoo` CE dalla repository ufficiale GitHub
  - `OCA/web` per moduli aggiuntivi
- Creazione e configurazione automatica del file `odoo.conf`
- Generazione di uno script di avvio `launch.sh` per il debug con `debugpy`

---

### 📦 Requisiti

- Ubuntu 20.04 o superiore
- Python ≥ 3.10

---

### 🚀 Istruzioni

1. Rendi eseguibile lo script:
   ```chmod +x odoo-install-dev.sh```
2. Esegui lo script con:
   ```./odoo-install.sh```

---

### 📁 Struttura delle Cartelle

- /home/odoo/odoo18 → Codice sorgente Odoo
- /home/odoo/venv/venv18 → Virtualenv Python
- /home/odoo/addons/addons18/OCA/web → Moduli OCA
- /home/odoo/odoo18/odoo.conf → File di configurazione
- /home/odoo/odoo18/logs/odoo.log → ```tail -f```  per visualizzare i logs
- /home/launch.sh → Script per avvio/debug rapido

---

### ❗ Attenzione

Lo script riavvia automaticamente il sistema alla fine per sistemare i permessi delle cartelle.
Puoi disattivare il riavvio modificando l'ultima riga dello script:
```sleep 30 && sudo reboot -h now```

---

### ✍️ Autore

Script creato per automatizzare ambienti di sviluppo Odoo da Netitup-MatteoSala 🚀