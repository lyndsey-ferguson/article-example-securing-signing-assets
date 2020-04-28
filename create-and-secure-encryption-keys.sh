#!/usr/bin/env sh

# Restrict standard system command line tools.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# make sure that any error exits the script immediately
set -e

read -p "Admin Vault Token: " VAULT_TOKEN

# create a random password for the private key
CRYPTO_PASSWORD="$(openssl rand -hex 20)"

# generate the private key in the process (no files written to disk)
PRIVATE_KEY="$(openssl genrsa -aes256 -passout pass:"$CRYPTO_PASSWORD" 8192)"
echo "$PRIVATE_KEY" > crypto.key

# encode the private key to text so we can put it into Vault
ENCODED_PRIVATE_KEY="$(echo "$PRIVATE_KEY" | base64 - | tr -d '\n')"

# generate the public key from the private key so that it can be used to encrypt data
echo "$PRIVATE_KEY" | openssl rsa -passin pass:"$CRYPTO_PASSWORD" -pubout -out vault/public-mobile-apps.key

# write the encoded private key and the private key password to Vault
curl \
   -H "X-Vault-Token: $VAULT_TOKEN" \
   -H "Content-Type: application/json" \
   -X POST \
   -d "{\"data\": {\"encoded_private_key\":\"$ENCODED_PRIVATE_KEY\", \"passphrase\": \"$CRYPTO_PASSWORD\"}}" \
     "http://127.0.0.1:8200/v1/secret/data/custom-mobile-apps/crypto"

unset VAULT_TOKEN
unset ENCODED_PRIVATE_KEY
unset CRYPTO_PASSWORD
