# this is the remote part of ncbkp. the main script ncbkp.sh should execute this script at your nextcloud server acting as the httpd user

# test remote paths
if [ ! -d $NC_WEBROOT ]; then 
	LOG e "remote: webroot path \"${NC_WEBROOT}\" doesnt exist. cancelling." && exit 1
else LOG s "remote: found webroot path \"${NC_WEBROOT}\""
fi

if [ ! -d $NC_CONFIG_PATH ]; then 
	LOG e "remote: config path \"${NC_CONFIG_PATH}\" doesnt exist. you might want to check that permissions are ok." && exit 1
else LOG s "remote: found config path \"${NC_CONFIG_PATH}\""
fi

if [ ! -d $NC_DATA ]; then
	LOG e "remote: data path \"${NC_DATA}\" doesnt exist. cancelling." && exit 1
else LOG s "remote: found data path \"${NC_DATA}\"" 
fi 

if [ ! -f ${OCC:4} ]; then 
	LOG e "remote: ${OCC:4} doesnt exist" && exit 1
else LOG s "remote: found nextcloud occ"
fi

# fetch database type and credentials

NC_CONFIG=${NC_WEBROOT}/config/config.php
DB_TYPE=$(cat $NC_CONFIG | grep dbtype | awk '{print $3}' | tr -d "',")
DB_HOST=$(cat $NC_CONFIG | grep dbhost | awk '{print $3}' | tr -d "',")
DB_NAME=$(cat $NC_CONFIG | grep dbname | awk '{print $3}' | tr -d "',")
DB_USER=$(cat $NC_CONFIG | grep dbuser | awk '{print $3}' | tr -d "',")
DB_PASS=$(cat $NC_CONFIG | grep dbpass | awk '{print $3}' | tr -d "',")

if [ -z $DB_TYPE ]; then 
	LOG e "remote: database could not be determined from config at $NC_CONFIG" && exit 1
else LOG s "remote: found $DB_TYPE database \"$DB_NAME"\"
fi 

# TODO: right now only supports mysql
if test $DB_TYPE != "mysql"; then LOG e "remote: could not determine database type. database not backed up." && db_backup=0; fi

# enable nextcloud maintenance mode
enabled=$(${OCC} maintenance:mode --on | grep -o -e enabled)
if [ -z $enabled ]; then 
	LOG e "remote: nextcloud maintenance mode not enabled" && exit 0
else LOG s "remote: nextcloud maintenance mode enabled"; fi
sleep 5

# backup database
mysqldump --single-transaction -h $DB_HOST -u $DB_USER -p"${DB_PASS}" $DB_NAME > $DB_BKP_PATH

if [ $? != 0 ]; then 
	LOG e "remote: nextcloud database backup failed. see mysqldump log."
else LOG s "remote: nextcloud database sucsessfully backed up to $DB_BKP_PATH"
fi
