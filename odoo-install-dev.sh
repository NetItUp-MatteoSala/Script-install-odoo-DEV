#!/bin/bash
################################################################################
# Questo script automatizza l'installazione di Odoo Community Edition (CE) 
# in un ambiente di sviluppo. 
#
# Istruzioni per l'uso:
# 1. Rendere eseguibile lo script con il comando: 
#    sudo chmod +x odoo-install-dev.sh
# 2. Eseguire lo script con il comando:
#    ./odoo-install-dev.sh
#
# Funzionalità principali:
# - Configurazione dell'ambiente di sviluppo per Odoo CE.
# - Installazione delle dipendenze necessarie, tra cui:
#   - PostgreSQL e librerie di sviluppo.
#   - wkhtmltopdf e font richiesti.
#   - Node.js, npm e rtlcss per il supporto LTR.
#   - Virtual Environment e pacchetti Python richiesti.
################################################################################

#####   VARIABILI DI CONFIGURAZIONE    #####
OE_VERSION="18.0"
OE_USER="odoo"
OE_PORT="8069"
OE_HOME="/home/$OE_USER"                                                         #/home/odoo
ODOO_MAJOR_VERSION=$(echo "$OE_VERSION" | cut -d'.' -f1)
OE_HOME_SRV="$OE_HOME/${OE_USER}${ODOO_MAJOR_VERSION}"                           #/home/odoo/odoo18
VENV_PATH="$OE_HOME/venv/venv${ODOO_MAJOR_VERSION}"                              #/home/odoo/venv18
CUSTOM_ADDONS="$OE_HOME/addons/addons${ODOO_MAJOR_VERSION}"                      #/home/odoo/addons/addons18

CURRENT_USER=$(whoami)
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')

cleanup() {
    local exit_code=$?
    echo -e "\n---- Lo script si arresterà ----"
    if [ $exit_code -ne 0 ]; then
        echo "Script interrotto: $1"
        echo "Codice di uscita: $exit_code"
    fi
}

trap 'cleanup' EXIT
trap 'cleanup "Ricevuto segnale di interruzione"' INT TERM

#####   VERIFICHE PRELIMINARI    #####
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "Questo script è progettato per sistemi Ubuntu"
    cleanup "Sistema operativo non supportato."
fi

if [ -z "$OE_VERSION" ]; then
    echo "Errore: $OE_VERSION non è impostata"
    echo "Imposta $OE_VERSION con una versione valida di Odoo (es. 14.0)"
    cleanup "Versione Odoo non specificata"
    exit 1
fi

echo -e "\n---- Verifico versione Python ----"

if [ "$(printf '3.10\n%s' "$PYTHON_VERSION" | sort -V | head -n1)" != "3.10" ]; then
    echo "⚠️  Errore: Odoo 18 richiede Python 3.10 o superiore"
    echo "Versione Python attuale: $PYTHON_VERSION"
    cleanup "Versione Python non compatibile"
    exit 1
fi

echo -e "\n---- Controllo se PostgreSQL è installato ----"
if ! command -v psql > /dev/null; then
    echo "PostgreSQL non è installato. Procedo con l'installazione..."
    sudo apt update
    sudo apt install -y postgresql postgresql-contrib libpq-dev postgresql-server-dev-all || {
        echo "❌ Impossibile installare PostgreSQL"
        exit 1
    }
    echo "✅ PostgreSQL installato con successo"
else
    echo "✅ PostgreSQL è già installato"
fi

echo -e "\n---- Creo utente Postgres Odoo  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

echo -e "\n---- Controllo e creo utente Postgres NIU o CSG se necessario ----"
NIU_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='NIU'")
CSG_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='CSG'")

if [[ "$NIU_EXISTS" == "1" || "$CSG_EXISTS" == "1" ]]; then
    echo "✅ Almeno uno tra 'NIU' o 'CSG' esiste già. Nessuna creazione necessaria."
else
    echo "Nessuno dei due utenti esiste. Creo 'NIU'..."
    sudo -u postgres createuser -s NIU
    echo "✅ Utente PostgreSQL 'NIU' creato con successo"
fi

echo -e "\n---- Aggiornamento del sistema ----"
sudo apt update && sudo apt upgrade -y

echo -e "\n---- Installo dipendenze di sistema ----"
sudo apt install -y \
    python3-minimal python3-dev python3-full python3-pip python3-venv python3-setuptools \
    build-essential libzip-dev libxslt1-dev libldap2-dev python3-wheel \
    libsasl2-dev node-less libjpeg-dev xfonts-utils libpq-dev libffi-dev \
    fontconfig git wget libcairo2-dev pkg-config \
    wkhtmltopdf xfonts-75dpi xfonts-base || {
    echo "❌ Installazione delle dipendenze di sistema fallita"
    exit 1
}

echo -e "\n---- Configuro Utente e directory Odoo ----"
if ! id "$OE_USER" &>/dev/null; then
    sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
    sudo adduser $OE_USER sudo
fi

echo -e "\n---- Clono le Repository Odoo e OCA/web ----"
if [ ! -d "$OE_HOME_SRV" ]; then
    sudo git clone https://github.com/odoo/odoo.git --depth 1 -b "$OE_VERSION" "$OE_HOME_SRV" || {
        echo "❌ Impossibile clonare la repository Odoo"
        exit 1
    }
fi

if [ ! -d "$CUSTOM_ADDONS/OCA/web" ]; then
    sudo git clone https://github.com/OCA/web.git --depth 1 -b "$OE_VERSION" "$CUSTOM_ADDONS/OCA/web" || {
        echo "❌ Impossibile clonare la repository OCA/web"
        exit 1
    }
fi

echo -e "\n---- Configuro l'Ambiente Virtuale Python ----"
if [ ! -d "$VENV_PATH" ]; then
    sudo -u $OE_USER python3 -m venv "$VENV_PATH" || {
        echo "❌ Impossibile creare l'ambiente virtuale"
        exit 1
    }
    sudo chown -R $OE_USER:$OE_USER "$VENV_PATH"
fi

echo -e "\n---- Installo le Dipendenze Python nel venv ----"
sudo -u $OE_USER $VENV_PATH/bin/pip install -r "$OE_HOME_SRV/requirements.txt" || {
    echo "❌ Impossibile installare i requisiti di Odoo"
    exit 1
}
sudo -u $OE_USER $VENV_PATH/bin/pip install debugpy jingtrang

#####   INSTALLAZIONE NODE.JS E RTLCSS    #####
echo -e "\n---- Installo nodeJS NPM e rtlcss per LTR support ----"
sudo apt install nodejs npm -y
sudo npm install -g rtlcss

#####   CONFIGURAZIONE FILE ODOO    #####
echo -e "\n---- Creo odoo.conf ----"
sudo tee "$OE_HOME_SRV/$OE_USER.conf" > /dev/null <<EOF
[options]
; Questo è il file di configurazione per $OE_USER
admin_passwd = admin
db_host = False
db_port = 5432
limit_time_cpu = 600
limit_time_real = 1800
data_dir = $OE_HOME/data
http_port = ${OE_PORT}
xmlrpc_port = ${OE_PORT}
logfile = $OE_HOME/$OE_USER$ODOO_MAJOR_VERSION/logs/odoo.log
addons_path = $OE_HOME_SRV/addons, $CUSTOM_ADDONS/OCA/web
EOF

sudo chown $OE_USER:$OE_USER "$OE_HOME_SRV/$OE_USER.conf"
sudo chmod 775 "$OE_HOME_SRV/$OE_USER.conf"


echo -e "\n---- Creo launch.sh per debug ----"
sudo touch "/home/launch.sh"
sudo bash -c "echo '
#!/bin/bash
sudo -u $OE_USER PATH=$PATH $VENV_PATH/bin/python3 -m debugpy --listen 5678 $OE_HOME_SRV/odoo-bin -c $OE_HOME_SRV/$OE_USER.conf --dev xml -u all' > /home/launch.sh"

sudo chmod 755 /home/launch.sh
sudo chmod +x "/home/launch.sh"

echo -e "\n---- Aggiusto i permessi delle cartelle ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME_SRV
sudo chown -R $OE_USER:$OE_USER $CUSTOM_ADDONS
sudo usermod -aG $OE_USER $CURRENT_USER


echo -e "\n                        Installazione di Odoo completata!                                                   "
echo "-----------------------------------------------------------------------------------------------------------------"
echo "                                  Ora puoi lanciare Odoo                                                         "
echo "                     per vedere i logs tail -f /home/odoo/odoo18/logs/odoo.log                                   "
echo "-----------------------------------------------------------------------------------------------------------------"

echo "-----------------------     Il sistema si riavvierà in 30 secondi...        -------------------------------------"
sleep 30 && sudo reboot -h now