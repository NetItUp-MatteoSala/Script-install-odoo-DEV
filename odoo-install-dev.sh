#!/bin/bash
################################################################################
# In your directory:
# sudo nano odoo-install-dev.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install-dev.sh
# Execute the script to install Odoo, its dependencies and automatically clone OCA/web:
# ./odoo-install-dev.sh
# 
# Questo script si occupa di installare Odoo CE su ambienti di sviluppo
################################################################################

#####   BEFORE YOU START    #####
#####   CHECK THE VERSION   #####

OE_VERSION=""
OE_USER="odoo"
OE_PORT="8069"
OE_HOME="/home/$OE_USER" 
OE_HOME_SRV="$OE_HOME/${OE_USER}-server{$OE_VERSION}"
VENV_PATH="$OE_HOME/odoo-venv/odoo-venv{$OE_VERSION}" # qui invece creo la cartella venv e dentro i vari odoo-venv18- 19- etc
CUSTOM_ADDONS= "$OE_HOME/custom-addons"  # qui ci butto oca/web

# Aggiorna i pacchetti di sistema
# Dovessero esserci errori di update sistema
# sudo nano /etc/apt/sources.list.d/ubuntu.sources
# Sostituire tutte le occorrenze di http://it.archive.ubuntu.com/ubuntu in http://archive.ubuntu.com/ubuntu

echo -e "\n---- Aggiornamento del sistema ----"
sudo apt update && sudo apt upgrade -y

echo -e "\n---- Installo Python e dipendenze di base ----"
sudo apt install -y python3-minimal python3-dev python3-pip python3-venv python3-setuptools build-essential libzip-dev libxslt1-dev libldap2-dev python3-wheel libsasl2-dev node-less libjpeg-dev xfonts-utils libpq-dev libffi-dev fontconfig git wget libcairo2-dev pkg-config wheel setuptools

echo -e "\n---- Installo PostgreSQL ----"
sudo apt install -y postgresql postgresql-server-dev-all

echo -e "\n---- Abilito PostgreSQL ----"
sudo systemctl start postgresql
sudo systemctl enable postgresql

echo -e "\n---- Creo utente odoo per il db ----"
if sudo -u postgres createuser -s "$OE_USER" 2>/dev/null; then
    echo "Utente PostgreSQL '$OE_USER' creato con successo."
else
    echo "Errore: impossibile creare l'utente PostgreSQL '$OE_USER'."
    echo "Verifica se l'utente esiste già con: sudo -u postgres psql -c \"\\du\""
fi

echo -e "\n---- Installo wkhtmltopdf ----"
sudo apt install -y wkhtmltopdf

echo -e "\n---- Creo utente odoo e lo aggiungo al gruppo odoo----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER

echo -e "\n---- Clono odoo in base alla versione selezionata ----"
sudo git clone https://github.com/odoo/odoo.git --depth 1 -b $OE_VERSION $OE_HOME_SRV

echo -e "\n---- Clono repository OCA/web in base alla versione selezionata ----"
sudo git clone https://github.com/OCA/web.git --depth 1 -b $OE_VERSION $CUSTOM_ADDONS/OCA/

echo -e "\n---- Creo il Virtual Environment ----"
sudo python3 -m venv $VENV_PATH

echo -e "\n---- Installo nodeJS NPM e rtlcss per LTR support ----"
sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss
sudo apt-get install xfonts-75dpi xfonts-base -y

echo -e "\n---- Creo odoo.conf ----"
sudo nano $OE_HOME/$OE_USER.conf > /dev/null <<EOF
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

addons_path = $OE_HOME_SRV/addons, $CUSTOM_ADDONS/OCA/web,
EOF

echo -e "\n---- Attivo il venv e installo requirements.txt di odoo e debugpy ----"




echo -e "\n                     ✅ Installazione di Odoo completata!"
echo "--------------------------------------------------------------------------------------------"
echo "                      Ora puoi accedere a Odoo tramite il tuo browser!"
echo "--------------------------------------------------------------------------------------------"