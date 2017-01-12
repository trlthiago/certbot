#!/bin/sh

#CRON
#00 05 * * * 
certbot renew --agree-tos --quiet --no-self-upgrade --renew-hook 'cp "$(sudo realpath $RENEWED_LINEAGE/cert.pem)" "$(sudo realpath $RENEWED_LINEAGE/cert.pem)-bkp-$(date +%y-%m-%d_%H:%M:%S)" && sudo cat "$RENEWED_LINEAGE/privkey.pem" >> "$RENEWED_LINEAGE/cert.pem"' --post-hook "systemctl reload httpd"
#test
