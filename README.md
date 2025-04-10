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

Per accedere via SQL client ricordarsi di editare i seguenti file 
/etc/postgresql/16/main/pg_hba.conf - aggiungere queste regole sostituendo le esistenti con:
```
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5
```

/etc/postgresql/16/main/postgresql.conf - scommentare riga 60 e sostituirla con:
```
listen_addresses = '*' 
```

Per accedere dall'esterno bisogna impostare una password all'utente NIU se non è già esistente

---

### ✍️ Autore

Script creato per automatizzare ambienti di sviluppo Odoo da Netitup-MatteoSala 🚀