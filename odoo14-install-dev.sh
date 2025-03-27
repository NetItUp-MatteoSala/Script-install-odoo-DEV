#!/bin/bash
################################################################################
# Script per l'installazione di Odoo CE in ambiente di sviluppo
# Uso: 
# 1. sudo chmod +x odoo-install-dev.sh
# 2. ./odoo-install-dev.sh
################################################################################

#####   VARIABILI DI CONFIGURAZIONE    #####
OE_VERSION="14.0"
OE_USER="odoo"
OE_PORT="8069"
OE_HOME="/home/$OE_USER"                                                 #/home/odoo
OE_HOME_SRV="$OE_HOME/${OE_USER}-server/${OE_USER}-server-${OE_VERSION}" #/home/odoo/odoo-server/odoo-server14
VENV_PATH="$OE_HOME/odoo-venv/odoo-venv-${OE_VERSION}"                   #/home/odoo/odoo-venv/odoo-venv14
CUSTOM_ADDONS="$OE_HOME/custom-addons${OE_VERSION}"                      #/home/odoo/custom-addons14

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
    echo "Errore: OE_VERSION non è impostata"
    echo "Imposta OE_VERSION con una versione valida di Odoo (es. 14.0)"
    cleanup "Versione Odoo non specificata"
    exit 1
fi

echo -e "\n---- Verifico versione Python ----"

if [ "$(printf '3.6\n%s' "$PYTHON_VERSION" | sort -V | head -n1)" != "3.6" ]; then
    echo "⚠️  Errore: Odoo 14 richiede Python 3.6 o superiore"
    echo "Versione Python attuale: $PYTHON_VERSION"
    cleanup "Versione Python non compatibile"
    exit 1
fi

echo -e "\n---- Verifico versione Postgres ----"

if ! command -v psql &> /dev/null; then
    echo "PostgreSQL non è installato. Procedo con l'installazione..."
    
    echo -e "\n---- Installo PostgreSQL ----"
    sudo apt install -y postgresql postgresql-server-dev-all
    
    echo -e "\n---- Abilito PostgreSQL ----"
    sudo systemctl start postgresql
    sudo systemctl enable postgresql

    PG_VERSION=$(psql -V | grep -oP '\d+' | head -1)

    if [ "$(printf '10\n%s' "$PG_VERSION" | sort -V | head -n1)" != "10" ]; then
        echo "⚠️  Errore: Odoo 14 richiede PostgreSQL 10 o superiore"
        echo "Versione PostgreSQL attuale: $PG_VERSION"
        cleanup "Versione PostgreSQL non compatibile"
        exit 1
    fi
    echo "✅ Versione PostgreSQL compatibile: $PG_VERSION"
fi

#####   INSTALLAZIONE WKHTMLTOPDF    #####
echo -e "\n---- Installo wkhtmltopdf e dipendenze ----"
sudo apt install -y wkhtmltopdf xfonts-75dpi xfonts-base

#####   CONFIGURAZIONE ODOO   #####
echo -e "\n---- Creo utente odoo e lo aggiungo al gruppo odoo----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER

echo -e "\n---- Creo directory necessarie ----"
sudo mkdir -p $OE_HOME/logs $OE_HOME/data $CUSTOM_ADDONS/OCA

echo -e "\n---- Clono odoo in base alla versione selezionata ----"
sudo git clone https://github.com/odoo/odoo.git --depth 1 -b $OE_VERSION $OE_HOME_SRV

echo -e "\n---- Clono repository OCA/web in base alla versione selezionata ----"
sudo git clone https://github.com/OCA/web.git --depth 1 -b $OE_VERSION $CUSTOM_ADDONS/OCA/web

#####   CONFIGURAZIONE AMBIENTE PYTHON    #####
echo -e "\n---- Creo il Virtual Environment ----"
sudo python3 -m venv $VENV_PATH

echo -e "\n---- Attivo il venv e installo requirements ----"
source $VENV_PATH/bin/activate
pip install --upgrade pip
pip install -r $OE_HOME_SRV/requirements.txt
pip install debugpy
deactivate

#####   INSTALLAZIONE NODE.JS E RTLCSS    #####
echo -e "\n---- Installo nodeJS NPM e rtlcss per LTR support ----"
sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss

#####   CONFIGURAZIONE FILE ODOO    #####
echo -e "\n---- Creo odoo.conf ----"
sudo nano $OE_HOME/$OE_USER.conf <<EOF
[options]
; Questo è il file di configurazione per $OE_USER
admin_passwd = admin
db_host = False
db_port = False
limit_time_cpu = 600
limit_time_real = 1800
data_dir = $OE_HOME/data
http_port = ${OE_PORT}
xmlrpc_port = ${OE_PORT}
logfile = $OE_HOME/logs/odoo.log
addons_path = $OE_HOME_SRV/addons,$CUSTOM_ADDONS/OCA/web
EOF

echo -e "\n---- Creo launch.sh per debug ----"
sudo nano $OE_HOME_SRV/launch.sh <<EOF
#!/bin/bash
$VENV_PATH/bin/python3 -m debugpy --listen 5678 $OE_HOME_SRV/odoo-bin -c $OE_HOME/$OE_USER.conf --dev xml -u all
EOF

#####   IMPOSTAZIONE PERMESSI    #####
echo -e "\n---- Imposto i permessi ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME
sudo chmod -R 755 $OE_HOME
sudo chown -R $OE_USER:$OE_USER $OE_HOME_SRV
sudo chmod -R 755 $OE_HOME_SRV
sudo chown -R $OE_USER:$OE_USER $VENV_PATH
sudo chmod -R 755 $VENV_PATH
sudo chown -R $OE_USER:$OE_USER $CUSTOM_ADDONS
sudo chmod -R 755 $CUSTOM_ADDONS
sudo chmod +x $OE_HOME_SRV/launch.sh

#####   COMPLETAMENTO    #####
echo -e "\n                     ✅ Installazione di Odoo completata!"
echo "--------------------------------------------------------------------------------------------"
echo "                      Ora puoi lanciare Odoo tramite lo script di lancio"
echo "                      cd /home/odoo/odoo-server/odoo-server${OE_VERSION} && ./launch.sh                 "
echo "--------------------------------------------------------------------------------------------"