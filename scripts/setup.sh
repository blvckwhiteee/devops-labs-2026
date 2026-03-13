#!/bin/bash
set -e

apt-get update
apt-get install -y nginx mariadb-server golang git curl sudo

if ! id "student" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo student
    echo "student ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/student
fi

if ! id "teacher" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo teacher
    usermod --password $(openssl passwd -6 12345678) teacher
    chage -d 0 teacher
fi

if ! id "mywebapp" &>/dev/null; then
    useradd -r -s /bin/false mywebapp
fi

if ! id "operator" &>/dev/null; then
    useradd -m -s /bin/bash -g operator operator
    usermod --password $(openssl passwd -6 12345678) operator
    chage -d 0 operator

    cat <<EOF > /etc/sudoers.d/operator
operator ALL=(ALL) NOPASSWD: /bin/systemctl start mywebapp.service, /bin/systemctl stop mywebapp.service, /bin/systemctl restart mywebapp.service, /bin/systemctl status mywebapp.service, /bin/systemctl reload nginx
EOF
fi

echo "12" > /home/student/gradebook
chown student:student /home/student/gradebook

systemctl start mariadb
systemctl enable mariadb

mysql <<EOF
CREATE DATABASE IF NOT EXISTS mywebapp_db;
CREATE USER IF NOT EXISTS 'appuser'@'127.0.0.1' IDENTIFIED BY 'secret';
CREATE USER IF NOT EXISTS 'appuser'@'localhost' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON mywebapp_db.* TO 'appuser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON mywebapp_db.* TO 'appuser'@'localhost';
FLUSH PRIVILEGES;
EOF

go build -o /usr/local/bin/mywebapp-migrate ./cmd/migrate
go build -o /usr/local/bin/mywebapp-server ./cmd/mywebapp

chown mywebapp:mywebapp /usr/local/bin/mywebapp-migrate /usr/local/bin/mywebapp-server
chmod 755 /usr/local/bin/mywebapp-migrate /usr/local/bin/mywebapp-server

DB_DSN="appuser:secret@tcp(127.0.0.1:3306)/mywebapp_db?parseTime=true"

cat <<EOF > /etc/systemd/system/mywebapp.socket
[Unit]
Description=My Web App Socket

[Socket]
ListenStream=127.0.0.1:3000

[Install]
WantedBy=sockets.target
EOF

cat <<EOF > /etc/systemd/system/mywebapp.service
[Unit]
Description=My Web App (Notes Service)
After=network.target mariadb.service
Requires=mariadb.service mywebapp.socket

[Service]
Type=simple
User=mywebapp
Group=mywebapp
Restart=on-failure
ExecStartPre=/usr/local/bin/mywebapp-migrate -db="${DB_DSN}"
ExecStart=/usr/local/bin/mywebapp-server -port=3000 -db="${DB_DSN}"
EOF

systemctl daemon-reload
systemctl enable mywebapp.socket
systemctl start mywebapp.socket

cat <<EOF > /etc/nginx/sites-available/mywebapp

server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/mywebapp_access.log;
    error_log /var/log/nginx/mywebapp_error.log;

    location /health {
        return 404;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

if id "ubuntu" &>/dev/null; then
    usermod -L -e 1 ubuntu
    echo "Користувач ubuntu заблокований."
fi

echo "Deployment has been finished!"