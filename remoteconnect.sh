#!/bin/bash

# Make sure we've got 2 extra things on the command line
if [ $# != "2" ]; then
  echo "Didn't pass the 2 passwords"
  exit 1
fi

# Get the MySQL Root Password
MYSQL_ROOT_PASSWORD="$1"

# Get the guacadmin password
GUAC_ADMIN_PASSWORD="$2"

# Setup the directories
GUAC_HOME="${HOME}/guacamole"
for DIRS in scripts sql db db/mysql; do
  mkdir -p ${GUAC_HOME}/${DIRS}
done

for ITEM in mysql guacamole/guacamole guacamole/guacd; do
  sudo docker pull ${ITEM}
done

# First setup the database
sudo docker run --name some-mysql -v ${GUAC_HOME}/db/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} -d mysql

echo <<E_O_F
CREATE DATABASE guacamole_db;
CREATE USER 'guacadmin'@'%' IDENTIFIED BY "${GUAC_ADMIN_PASSWORD}";
GRANT ALL ON guacamole_db.* TO 'guacadmin'@'%';
FLUSH PRIVILEGES;
USE guacamole_db;
E_O_F >> ${GUAC_HOME}/sql/initdb.mysql.sql

sudo docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --mysql >> ${GUAC_HOME}/sql/initdb.mysql.sql

sudo docker exec -i some-mysql sh -c "exec mysql -uroot -p${MYSQL_ROOT_PASSWORD}" < ${GUAC_HOME}/sql/initdb.mysql.sql

# Now setup guacd
sudo docker run --name some-guacd -d -p 4822:4822 guacamole/guacd

# Now setup guacamole
docker run --name some-guacamole --link some-guacd:guacd \
    --link some-mysql:mysql      \
    -e MYSQL_DATABASE=guacamole_db  \
    -e MYSQL_USER=guacadmin    \
    -e MYSQL_PASSWORD=${GUAC_ADMIN_PASSWORD} \
    -d -p 8080:8080 guacamole/guacamole

echo "You can now goto:"
echo "http://`hostname`:8080/guacamole"
echo "or"
echo "http://`host ${HOSTNAME} | awk '{print $NF}'`:8080/guacamole"
