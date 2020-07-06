#!/usr/bin/env sh

# Restrict standard system command line tools.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

set -e
set -x

###############################################################################
# Checks whether or not the VAULT_TOKEN can be used to create or update
# the Vault secret at the given secret path.
# Globals:
#   VAULT_TOKEN
# Arguments:
#   a path to the secret in Vault. i.e. 'secret/data/custom-mobile-apps/keychains/example_corporation'
###############################################################################
check_token_for_create_update_capabilities() {
  local secret_path
  secret_path=$1

  capabilities=$(curl -s --request POST --header "X-Vault-Token: $VAULT_TOKEN" \
    --data "{\"path\":\"$secret_path\"}" \
    http://127.0.0.1:8200/v1/sys/capabilities-self | jq  ".capabilities")

  has_create_update_capabilities="$(echo $capabilities | jq "[. | sort | index(\"create\"), index(\"update\")] == [0, 1]")"

  if [ "$has_create_update_capabilities" == "false" ]; then
    echo "Error: current VAULT_TOKEN does not allow to write to '$secret_path'"
    exit 1
  fi
}

# Make sure that we can write keychains and apns_keys secrets
check_token_for_create_update_capabilities "secret/data/custom-mobile-apps/keychains/*"
check_token_for_create_update_capabilities "secret/data/custom-mobile-apps/apns_keys/*"

# Ensure the 1st parameter to script is a keychain, and 2nd is an APNS key
KEYCHAIN_FILEPATH=$1
if [ ! -f "$KEYCHAIN_FILEPATH" ]; then
  echo "Error: the first parameter must be an existing keychain filepath"
  exit 1
fi
APNS_PRIVATE_KEY_FILE_PATH=$2
if [ ! -f "$APNS_PRIVATE_KEY_FILE_PATH" ]; then
  echo "Error: the second parameter must be an existing APNS key filepath"
  exit 1
fi

if [[ -z ${KEYCHAIN_PASSWORD+x} ]]; then
  read -sp "Keychain password: " KEYCHAIN_PASSWORD
fi
echo ""

# we need to make sure that codesigning can be done by Apple without a GUI prompting the system
security set-key-partition-list -S "apple-tool:,apple:,/usr/bin/codesign"  -k "$KEYCHAIN_PASSWORD" "${KEYCHAIN_FILEPATH}" 

# Vault does not support storing and retrieving binary data: we need to encode
# binary data into base64 in order to put it into Vault (remove extra newlines)
KEYCHAIN_ENCODED_DATA="$(base64 -b 0 "$KEYCHAIN_FILEPATH")"


ENCRYPTED_KEYCHAIN_PASSWORD_FILEPATH=$(mktemp /tmp/encrypted-keychain-password.enc.XXXXXX)
rm $ENCRYPTED_KEYCHAIN_PASSWORD_FILEPATH
echo "$KEYCHAIN_PASSWORD" | tr -d '\n' | openssl rsautl -encrypt -pubin -inkey $HERE/vault/public-mobile-apps.key -out $ENCRYPTED_KEYCHAIN_PASSWORD_FILEPATH

ENCODED_ENCRYPTED_KEYCHAIN_PASSWORD="$(cat "$ENCRYPTED_KEYCHAIN_PASSWORD_FILEPATH" | base64 -b 0)"
rm "$ENCRYPTED_KEYCHAIN_PASSWORD_FILEPATH" # Delete the password file, just to be safe
if [[ -z ${COMPANY_NAME+x} ]]; then
  read -p "Company name: " COMPANY_NAME
fi

echo ""
echo "$ENCODED_ENCRYPTED_KEYCHAIN_PASSWORD" > "${COMPANY_NAME}-encoded-encrypted-keychain-password.enc"

# POST to the Vault server in order to write the keychain and the encrypted
# keychain password for the customer.
curl \
 -H "X-Vault-Token: $VAULT_TOKEN" \
 -H "Content-Type: application/json" \
 -X POST \
 -d "{\"data\": {\"keychain_encoded_data\":\"$KEYCHAIN_ENCODED_DATA\", \"encoded_encrypted_keychain_password\": \"$ENCODED_ENCRYPTED_KEYCHAIN_PASSWORD\"}}" \
 "http://127.0.0.1:8200/v1/secret/data/custom-mobile-apps/keychains/$COMPANY_NAME"

# Delete the encoded encrypted file, just to be safe
rm "${COMPANY_NAME}-encoded-encrypted-keychain-password.enc"

# POST to the Vault server in order to write the encrypted APNS key for the customer.
APNS_JSON_FILEPATH=$(mktemp /tmp/APNS_JSON.json.XXXXXX)
cat > $APNS_JSON_FILEPATH <<- EOF
 {
   "data": {
     "apns_private_key": "$(cat $APNS_PRIVATE_KEY_FILE_PATH)"
   }
 }
EOF

curl \
 -H "X-Vault-Token: $VAULT_TOKEN" \
 -H "Content-Type: application/json" \
 -X POST "http://127.0.0.1:8200/v1/secret/data/custom-mobile-apps/apns_keys/$COMPANY_NAME" \
 -d @$APNS_JSON_FILEPATH

echo "Keychain data secured into Vault"

unset ENCODED_ENCRYPTED_KEYCHAIN_PASSWORD
unset ENCRYPTED_KEYCHAIN_PASSWORD_FILEPATH
unset KEYCHAIN_ENCODED_DATA
unset APNS_PRIVATE_KEY_FILE_PATH
unset KEYCHAIN_FILEPATH
