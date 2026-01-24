#!/bin/bash
# Token from DuckDNS dashboard
TOKEN="VOTRE_TOKEN_ICI"
DOMAIN="karim-exam-devops"
IP=$(curl -s http://checkip.amazonaws.com)

echo "Updating DuckDNS for $DOMAIN with IP $IP..."
curl -s "https://www.duckdns.org/update?domains=$DOMAIN&token=$TOKEN&ip=$IP"
echo -e "\nDone."
