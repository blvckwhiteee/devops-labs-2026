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
    usermod --password "$(openssl passwd -6 12345678)" teacher
    chage -d 0 teacher
fi

if ! id "app" &>/dev/null; then
    useradd -r -s /bin/false app
fi

if ! id "operator" &>/dev/null; then
    useradd -m -s /bin/bash -g operator operator
    usermod --password "$(openssl passwd -6 12345678)" operator
    chage -d 0 operator

    cat <<EOF > /etc/sudoers.d/operator
operator ALL=(ALL) NOPASSWD: /bin/systemctl start mywebapp.service, /bin/systemctl stop mywebapp.service, /bin/systemctl restart mywebapp.service, /bin/systemctl status mywebapp.service, /bin/systemctl reload nginx
EOF
fi

echo "12" > /home/student/gradebook
chown student:student /home/student/gradebook

systemctl start mariadb
systemctl enable mariadb
mysql < scripts/init_db.sql

go build -o /usr/local/bin/mywebapp-migrate ./cmd/migrate
go build -o /usr/local/bin/mywebapp-server ./cmd/mywebapp

chown app:app /usr/local/bin/mywebapp-migrate /usr/local/bin/mywebapp-server
chmod 755 /usr/local/bin/mywebapp-migrate /usr/local/bin/mywebapp-server

cp configs/mywebapp.socket /etc/systemd/system/
cp configs/mywebapp.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable mywebapp.socket
systemctl start mywebapp.socket

cp configs/nginx.conf /etc/nginx/sites-available/mywebapp

ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

if id "ubuntu" &>/dev/null; then
    usermod -L -e 1 ubuntu
    echo "Користувач ubuntu заблокований."
fi

echo "Deployment has been finished"