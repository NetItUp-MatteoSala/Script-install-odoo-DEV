#!/bin/bash
################################################################################
# Script per l'installazione di Odoo CE in ambiente di sviluppo
# Uso: 
# 1. sudo chmod +x odoo-install-dev.sh
# 2. ./odoo-install-dev.sh
################################################################################

#####   VARIABILI DI CONFIGURAZIONE    #####
OE_VERSION=""
OE_USER="odoo"
OE_PORT="8069"
OE_HOME="/home/$OE_USER"
OE_HOME_SRV="$OE_HOME/${OE_USER}-server-${OE_VERSION}"
VENV_PATH="$OE_HOME/odoo-venv/odoo-venv-${OE_VERSION}"
CUSTOM_ADDONS="$OE_HOME/custom-addons"  # Rimosso spazio dopo =

#####   VERIFICHE PRELIMINARI    #####
# Verifica se è stata specificata la versione
if [ -z "$OE_VERSION" ]; then
    echo "Errore: OE_VERSION non è impostata"
    echo "Imposta OE_VERSION con una versione valida di Odoo (es. 16.0, 17.0)"
    exit 1
fi

# Verifica se lo script è eseguito come root
if [ "$(id -u)" != "0" ]; then
   echo "Questo script deve essere eseguito come root" 
   exit 1
fi

# Verifica Ubuntu e versione
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "Questo script è progettato per sistemi Ubuntu"
    exit 1
fi

# Verifica versione specifica di Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)
if [ -z "$UBUNTU_VERSION" ]; then
    echo "Impossibile determinare la versione di Ubuntu"
    exit 1
fi

echo -e "\n---- Verifico compatibilità versione Ubuntu ----"
if (( $(echo "$UBUNTU_VERSION < 20.04" | bc -l) )); then
    echo "Questo script richiede Ubuntu 20.04 o superiore"
    echo "Versione attuale: $UBUNTU_VERSION"
    exit 1
fi

echo -e "\n---- Aggiornamento del sistema ----"
sudo apt update && sudo apt upgrade -y

echo -e "\n---- Installo Python e dipendenze di base ----"
sudo apt install -y python3-minimal python3-dev python3-pip python3-venv python3-setuptools \
    build-essential libzip-dev libxslt1-dev libldap2-dev python3-wheel libsasl2-dev node-less \
    libjpeg-dev xfonts-utils libpq-dev libffi-dev fontconfig git wget libcairo2-dev pkg-config \
    wheel setuptools

#####   INSTALLAZIONE POSTGRESQL    #####
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

#####   INSTALLAZIONE WKHTMLTOPDF    #####
echo -e "\n---- Installo wkhtmltopdf e dipendenze ----"
sudo apt install -y wkhtmltopdf xfonts-75dpi xfonts-base

#####   CONFIGURAZIONE ODOO    #####
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
sudo tee $OE_HOME/$OE_USER.conf > /dev/null <<EOF
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
sudo tee $OE_HOME_SRV/launch.sh > /dev/null <<EOF
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
echo "                      cd /home/odoo/odoo-server${OE_VERSION} && ./launch.sh                 "
echo "--------------------------------------------------------------------------------------------"