#!/bin/bash
# Создаёт постоянный самоподписанный сертификат для подписи приложения.
# Нужен, чтобы выданные разрешения (микрофон, Универсальный доступ) не слетали
# после каждой пересборки: с ad-hoc подписью macOS считает новую сборку другим приложением.
set -e

NAME="Nier Voice Self"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if security find-identity -v -p codesigning | grep -q "$NAME"; then
    echo "сертификат «$NAME» уже есть"
    exit 0
fi

cat > "$TMP/ext.cnf" <<EXT
[req]
distinguished_name = dn
prompt = no
[dn]
CN = $NAME
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EXT

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -config "$TMP/ext.cnf" -extensions v3 2>/dev/null

openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout pass:niervoice -name "$NAME" 2>/dev/null

security import "$TMP/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P niervoice -T /usr/bin/codesign -A >/dev/null

echo "сертификат «$NAME» создан"
