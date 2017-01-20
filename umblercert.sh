#!/bin/sh

#URL="https://github.com/trlthiago/certbot/archive/vUmbler0.9.3.zip"
#URL="https://github.com/certbot/certbot/archive/v0.10.0.zip"
URL="https://github.com/certbot/certbot/archive/v0.10.1.zip"
AUTO="https://raw.githubusercontent.com/certbot/certbot/master/certbot-auto"

VENV_NAME="umblercert"
BASE_DIR="/home/umbler/ubpainel"
VENV_PATH="$BASE_DIR/$VENV_NAME"

DownloadNewVersion(){
    echo "Downloading...";
    sudo wget --output-document /var/tmp/certbotumbler.zip $URL --quiet
}

UnzipFile(){
    echo "Unzipping...";
    sudo unzip -qqo /var/tmp/certbotumbler.zip -d /var/tmp/
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
        echo "Removing python-setuptools!!!"
        yum remove python-setuptools -y
        wget https://bootstrap.pypa.io/ez_setup.py -O - | python
    fi
}

InstallBot(){
    echo "Installing...";

    FOLDER=$(unzip -qql /var/tmp/certbotumbler.zip | head -n1 | tr -s ' ' | cut -d ' ' -f 5)
    INSTALLATION_FOLDER="/var/tmp/"$FOLDER
    echo "Switching to $INSTALLATION_FOLDER"
    cd $INSTALLATION_FOLDER

    ./certbot-auto --os-packages-only --non-interactive
}


InstallBotOld(){
    echo "Installing...";

    #if [ -f /etc/redhat-release ]; then
    #    UpgradeSetupTools
    #fi

    FOLDER=$(unzip -qql /var/tmp/certbotumbler.zip | head -n1 | tr -s ' ' | cut -d ' ' -f 5)
    INSTALLATION_FOLDER="/var/tmp/"$FOLDER
    echo "Switching to $INSTALLATION_FOLDER"
    cd $INSTALLATION_FOLDER

    if [ -f /etc/debian_version ]; then
        sudo apt-get install libffi-dev -y
    elif [ -f /etc/redhat-release ]; then
        sudo yum install libffi-devel -y
        sudo yum install python-devel -y
    else
        echo "It was not possible to determine what SO is running!";
    fi

    #python -m easy_install -U requests
    python -m easy_install -U cryptography; if [ "$?" != "0" ]; then echo "Woops!"; exit 1; fi
    python -m easy_install -U pyOpenSSL; if [ "$?" != "0" ]; then echo "Woops!"; exit 1; fi

    sudo yum install python2-pip -y; if [ "$?" != "0" ]; then echo "Woops!"; exit 1; fi
    pip install -U setuptools; if [ "$?" != "0" ]; then echo "Woops!"; exit 1; fi
    pip install -U pip; if [ "$?" != "0" ]; then echo "Woops!"; exit 1; fi
    pip install requests --upgrade; if [ "$?" != "0" ]; then echo "Woops!"; exit 1; fi
    #pip install pyonpenssl --upgrade

    python setup.py clean --all
    python setup.py install; if [ "$?" != "0" ]; then echo "Woops!"; exit 1; fi

    if [ "$?" != "0" ]; then
        echo "Woops!"
        exit 1
    fi

    cd -
}

UninstallPreviousVersion(){
    echo "Uninstalling previous version...";
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

InstallNewVersion(){
    echo "Installing new version...";
    DownloadNewVersion
    UnzipFile
    InstallBot
    ClearTemporaryFiles
    ConfigureRenewCron
}

ConfigureRenewCron(){
    echo "Configuring Cron...";
    RemoveCron
    #sudo echo "00 05 * * * certbot renew --agree-tos --quiet --no-self-upgrade --renew-hook 'cp \"\$(sudo realpath \$RENEWED_LINEAGE/cert.pem)\" \"\$(sudo realpath \$RENEWED_LINEAGE/cert.pem)-bkp-\$(date +%y-%m-%d_%H:%M:%S)\" && sudo cat \"\$RENEWED_LINEAGE/privkey.pem\" >> \"\$RENEWED_LINEAGE/cert.pem\"' --post-hook \"systemctl reload httpd\"" >> /var/spool/cron/root
    
    sudo echo "00 05 * * 6,0 (certbot-auto renew --agree-tos --quiet; systemctl reload httpd)" >> /var/spool/cron/root 
    

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

DetectCertbot2(){
    command -v "certbot" > /dev/null 
    if [ "$?" != "0" ]; then
        SETUPTOOLS=$(yum list installed | grep certbot)
        if [[ -z "$SETUPTOOLS" ]]; then
            echo "certbot not found on yum, So it should be new version already."
            echo "Everything OK!"
        else
            UninstallPreviousVersion
            InstallNewVersion
        fi
    else
        InstallNewVersion
    fi
}

InstallAuto(){
    sudo wget --output-document /var/tmp/certbot-auto $AUTO --quiet
    sudo chmod +x /var/tmp/certbot-auto
    /var/tmp/certbot-auto --os-packages-only --non-interactive
    cp /var/tmp/certbot-auto /usr/bin/certbot-auto
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
            InstallNewVersion
        fi
    else
        if [ "$USING_VENV" = 1 ]; then
            UninstallPreviousVersion
            CreateAndDeployVirtualEnvironment
        else
            OUTPUT=$(certbot umbler --quiet)
            case "$OUTPUT" in 
                *Umbler*|*umbler*) 
                    echo "Everything OK!";;
                *) 
                    UninstallPreviousVersion
                    InstallNewVersion;;
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

case "$1" in
    --force)
        UninstallPreviousVersion
        InstallNewVersion;;
    --remove)
        UninstallPreviousVersion
        RemoveCron;;
    --download)
        DownloadNewVersion
        UnzipFile;;
    --virtual)
        USING_VENV=1
        DetectCertbot;;
    --call)
        Call $@;;
    --force-auto)
        UninstallPreviousVersion
        InstallAuto;;
    *) DetectCertbot2;;
esac