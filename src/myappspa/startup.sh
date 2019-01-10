#!/bin/bash
cat >/etc/motd <<EOL 
  _____                               
  /  _  \ __________ _________   ____  
 /  /_\  \\___   /  |  \_  __ \_/ __ \ 
/    |    \/    /|  |  /|  | \/\  ___/ 
\____|__  /_____ \____/ |__|    \___  
        \/      \/                  \/ 
EOL

cat /etc/motd

sed -i -e "s/#TODOAPIURL#/${TODOAPIURL/'//'/'\/\/'}/" /var/www/js/app.js 
sed -i -e "s/#INSTANCENAME#/$(cat /etc/hostname)/" /var/www/js/app.js 
sed -i -e "s/#INSTANCEVERSION#/$(cat /version)/" /var/www/js/app.js 

nginx
