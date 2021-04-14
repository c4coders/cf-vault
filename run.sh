#!/bin/sh

# PostgreSQL backend store
# 	connection sslmode=disable
#		instance 	 vault-db
#		database	 vault-db
#		table(s)	 vault_kv_store

POSTGRESQL=`echo $VCAP_SERVICES | grep "postgresql"`

if [ "$POSTGRESQL" != "" ]; then
	SERVICE="postgresql"
else
	echo "No PostgreSQL detected"
	exit 1
fi

echo "detected $SERVICE"

DBHOSTNAME=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.hostname'`
DBPASSWORD=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.password'`
DBPORT=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.port'`
DBUSERNAME=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.username'`
DATABASE=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.name'`

cat <<EOF > cf.hcl
disable_mlock = true

api_addr = "https://$APPNAME.$CF_API"

storage "postgresql" {
	connection_url = "postgres://$DBUSERNAME:$DBPASSWORD@$DBHOSTNAME:$DBPORT/vaultdb?sslmode=disable"
	table = "vault_kv_store"
	max_parallel = 4
}

listener "tcp" {
 address = "0.0.0.0:$PORT"
 tls_disable = 1
}

ui = "true"

EOF

echo "#### Starting Vault..."

./vault server -config=cf.hcl &

if [ "$VAULT_UNSEAL_KEY1" != "" ];then
	export VAULT_ADDR='http://127.0.0.1:$PORT'
	echo "#### Waiting..."
	sleep 1
	echo "#### Unsealing..."
	if [ "$VAULT_UNSEAL_KEY1" != "" ];then
		./vault unseal $VAULT_UNSEAL_KEY1
	fi
	if [ "$VAULT_UNSEAL_KEY2" != "" ];then
		./vault unseal $VAULT_UNSEAL_KEY2
	fi
	if [ "$VAULT_UNSEAL_KEY3" != "" ];then
		./vault unseal $VAULT_UNSEAL_KEY3
	fi
fi
