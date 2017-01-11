#!/bin/sh

URL="https://github.com/trlthiago/certbot/archive/umbler0.9.3.zip"

DownloadUmblerVersion(){
    echo "Downloading...";
    #sudo wget -O -q /var/tmp/certbotumbler.zip https://github.com/trlthiago/certbot/archive/Umbler1.0.zip
    sudo wget --output-document /var/tmp/certbotumbler.zip $URL --quiet
}

UnzipFile(){
    echo "Unzipping...";
    sudo unzip -qq /var/tmp/certbotumbler.zip -d /var/tmp/
}

InstallBot(){
    echo "Installing...";
    FOLDER=$(unzip -qql /var/tmp/certbotumbler.zip | head -n1 | tr -s ' ' | cut -d ' ' -f 5)
    INSTALLER="/var/tmp/"$FOLDER"setup.py"
    sudo python $INSTALLER install
}

UninstallPreviousBot(){
    echo "Uninstalling previous...";
    BINARY=$(command -v "certbot")
    echo "Found $BINARY"
    sudo pip uninstall certbot -y
    sudo rm -f $BINARY
    #sudo rm -Rf   
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

DetectCertbot(){
    command -v "certbot" > /dev/null 
    if [ "$?" != "0" ]; then
        echo "Cannot find any certbot!";
        InstallUmblerVersion
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
} 

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
    *) DetectCertbot;;
esac