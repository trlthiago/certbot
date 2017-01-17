#!/bin/sh

URL="https://github.com/trlthiago/certbot/archive/vUmbler0.9.3.zip"
#URL="https://github.com/certbot/certbot/archive/v0.10.0.zip"
VENV_NAME="umblercert"
BASE_DIR="/home/umbler/ubpainel"
VENV_PATH="$BASE_DIR/$VENV_NAME"

DownloadUmblerVersion(){
    echo "Downloading...";
    sudo wget --output-document /var/tmp/certbotumbler.zip $URL --quiet
}

UnzipFile(){
    echo "Unzipping...";
    sudo unzip -qq /var/tmp/certbotumbler.zip -d /var/tmp/
}

UpgradeSetupTools(){
    #TODO: check if setuptools>=1.0 is installed
    SETUPTOOLS=$(yum list installed | grep setuptools)
    if [[ -z "$SETUPTOOLS" ]]; then
        echo "setuptools not found on yum."
        #trying get by python
        SETUPTOOLS=$(python -m easy_install --version | awk '{print $2}')
        if [[ $SETUPTOOLS == 0.* ]]; then
            echo "found $SETUPTOOLS version. Installing a new version"
            wget https://bootstrap.pypa.io/ez_setup.py -O - | python
        fi
    else

        yum remove python-setuptools
        wget https://bootstrap.pypa.io/ez_setup.py -O - | python
    fi
}

InstallBot(){
    echo "Installing...";

    #if [ -f /etc/redhat-release ]; then
    #    UpgradeSetupTools
    #fi
    
    FOLDER=$(unzip -qql /var/tmp/certbotumbler.zip | head -n1 | tr -s ' ' | cut -d ' ' -f 5)
    INSTALLATION_FOLDER="/var/tmp/"$FOLDER
    echo "Switching to $INSTALLATION_FOLDER"
    cd $INSTALLATION_FOLDER
    python setup.py clean --all
    python setup.py install

    if [ "$?" != "0" ]; then
        echo "Woops!"
        exit 1
    fi

    cd -
}

UninstallPreviousBot(){
    echo "Uninstalling previous...";
    BINARY=$(command -v "certbot")
    echo "Found $BINARY"

    if [ -f /etc/redhat-release ]; then
        sudo  yum remove "*certbot*" -y
    fi

    sudo pip uninstall certbot -y
    sudo rm -f $BINARY
}

ClearTemporaryFiles(){
    echo "Cleaning temp files...";
    FOLDER=$(unzip -qql /var/tmp/certbotumbler.zip | head -n1 | tr -s ' ' | cut -d ' ' -f 5)
    sudo rm -Rf /var/tmp/$FOLDER /var/tmp/certbotumbler.zip
}

InstallUmblerVersion(){
    echo "Installing Umbler version...";
    DownloadUmblerVersion
    UnzipFile
    InstallBot
    ClearTemporaryFiles
    ConfigureRenewCron
}

ConfigureRenewCron(){
    echo "Configuring Cron...";
    RemoveCron
    sudo echo "00 05 * * * certbot renew --agree-tos --quiet --no-self-upgrade --renew-hook 'cp \"\$(sudo realpath \$RENEWED_LINEAGE/cert.pem)\" \"\$(sudo realpath \$RENEWED_LINEAGE/cert.pem)-bkp-\$(date +%y-%m-%d_%H:%M:%S)\" && sudo cat \"\$RENEWED_LINEAGE/privkey.pem\" >> \"\$RENEWED_LINEAGE/cert.pem\"' --post-hook \"systemctl reload httpd\"" >> /var/spool/cron/root
    
    if [ -f /etc/debian_version ]; then
        sudo /etc/init.d/cron restart
    elif [ -f /etc/redhat-release ]; then
        sudo systemctl reload crond
    else
        echo "It was not possible to determine what SO is running!";
    fi
}

RemoveCron(){
    sudo sed -i '/certbot/d' /var/spool/cron/root
}

DeterminePythonVersion() {
#   for LE_PYTHON in "$LE_PYTHON" python2.7 python27 python2 python; do
#     # Break (while keeping the LE_PYTHON value) if found.
#     command -v "$LE_PYTHON" > /dev/null && break
#   done
#   if [ "$?" != "0" ]; then
#     echo "Cannot find any Pythons; please install one!"
#     exit 1
#   fi
#   echo "Found $LE_PYTHON !"
#   export LE_PYTHON

#   /usr/bin/python3.5m 
#   /usr/bin/python 
#   /usr/bin/python3.5 
#   /usr/bin/python2.7 
#   /usr/bin/python2.7-config 
#   /usr/lib/python3.5 /usr/lib/python2.7 /etc/python /etc/python3.5 /etc/python2.7 /usr/local/lib/python3.5 /usr/local/lib/python2.7 /usr/include/python3.5m /usr/include/python2.7 /usr/share/python /home/umblerbot/bin/python /home/umblerbot/bin/python2.7 /usr/share/man/man1/py

#   PYVER=`"$LE_PYTHON" -V 2>&1 | cut -d" " -f 2 | cut -d. -f1,2 | sed 's/\.//'`
#   if [ "$PYVER" -lt 26 ]; then
#     echo "You have an ancient version of Python entombed in your operating system..."
#     echo "This isn't going to work; you'll need at least version 2.6."
#     exit 1
#   fi
    LE_PYTHON="/home/umblerbot/bin/python"
    export LE_PYTHON
}

CreateAndDeployVirtualEnvironment(){
    echo "Creating Virtual Environment..."
    sudo mkdir $BASE_DIR -p
    cd $BASE_DIR
    sudo virtualenv --no-site-packages $VENV_NAME --python python2
    echo "We are in: $VIRTUAL_ENV"
    . $VENV_PATH/bin/activate

     if [ "$?" != "0" ]; then
        echo "Woops! Error to activate the virtualenv :'("
        exit 1
    else 
        echo "We are in: $VIRTUAL_ENV"
    fi
    
    pip install -U setuptools
    pip install -U pip
    
    # if [ -f /etc/debian_version ]; then
    #     sudo apt-get install libffi-dev -y
    # elif [ -f /etc/redhat-release ]; then
    #     sudo yum install libffi-devel -y
    # else
    #     echo "It was not possible to determine what SO is running!";
    # fi
    InstallUmblerVersion
}

DetectCertbot(){
    command -v "certbot" > /dev/null 
    if [ "$?" != "0" ]; then
        echo "Cannot find any system-based certbot!";
        if [ "$USING_VENV" = 1 ]; then
            if [ -d "$VENV_PATH" ]; then
                #TODO: In the feature, check if it is an update. If it does, we should remove the folder and recreate it.
                echo "Virtualenv $VENV_PATH already exists!"
                echo "Everything OK!"
                #InstallUmblerVersion
            else
                echo "$VENV_PATH doesnt exists!"
                CreateAndDeployVirtualEnvironment
            fi
        else
            InstallUmblerVersion
        fi
    else
        if [ "$USING_VENV" = 1 ]; then
            UninstallPreviousBot
            CreateAndDeployVirtualEnvironment
        else
            OUTPUT=$(certbot umbler --quiet)
            case "$OUTPUT" in 
                *Umbler*|*umbler*) 
                    echo "Everything OK!";;
                *) 
                    UninstallPreviousBot
                    InstallUmblerVersion;;
            esac
        fi
    fi
} 

Call(){
    #echo "We are in: $VIRTUAL_ENV"
    . $VENV_PATH/bin/activate
    #echo "We are in: $VIRTUAL_ENV"
    shift
    certbot $@
}

#DeterminePythonVersion

case "$1" in
    --force)
        UninstallPreviousBot
        InstallUmblerVersion;;
    --remove)
        UninstallPreviousBot
        RemoveCron;;
    --download)
        DownloadUmblerVersion
        UnzipFile;;
    --virtual)
        USING_VENV=1
        DetectCertbot;;
    --call)
        Call $@;;
    *) DetectCertbot;;
esac