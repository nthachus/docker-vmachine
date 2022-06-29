#!/bin/sh
set -e

# OpenSSL config file
_SSL_CONF="${TMPDIR:=/tmp}/docker-ssl.cnf"

cp -f "$(dirname "$0")/${_SSL_CONF##*/}" "$TMPDIR"
echo "IP.3 = ${1:-$(ip r | grep '\.0/' | sed 's,\.0/.*,.128,')}" >> "$_SSL_CONF"

# Create self-signed CA
# openssl genrsa -des3 -out ca-key.pem
[ -s ca-key.pem ] || openssl genrsa -out ca-key.pem

openssl req -x509 -new -key ca-key.pem -out ca.pem -nodes -sha256 -days 3650 -subj "/O=Docker CE" -config "$_SSL_CONF"
openssl x509 -text -noout -in ca.pem > ca.txt

# Create server certificate
[ -s server-key.pem ] || openssl genrsa -out server-key.pem
openssl req -new -key server-key.pem -out server.csr -nodes -sha256 -subj "/O=Docker CE/CN=docker-machine" \
    -config "$_SSL_CONF"

openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem -sha256 -days 3650 \
    -extfile "$_SSL_CONF" -extensions server_ext
openssl x509 -text -noout -in server.pem > server.txt

# Create client certificate
[ -s key.pem ] || openssl genrsa -out key.pem
openssl req -new -key key.pem -out client.csr -nodes -subj "/O=Docker CE/CN=docker-bootstrap" -config "$_SSL_CONF"

openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -days 3650 \
    -extfile "$_SSL_CONF" -extensions client_ext
openssl x509 -text -noout -in cert.pem > cert.txt

# Generate SSH key
[ -s id_rsa ] || ssh-keygen -t rsa -b 2048 -q -C "docker@lvh.me" -N "" -f id_rsa || true

# Cleanup
if [ ! -s certificates.tgz ]; then
  tar -czf certificates.tgz *.pem id_rsa* || true; rm -f *.pem id_rsa*
fi
rm -f *.srl *.csr
