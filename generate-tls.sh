#!/bin/sh
set -e

# create self-signed CA
[ -s ca-key.pem ] || openssl genrsa -out ca-key.pem
# openssl genrsa -des3 -out ca-key.pem
openssl req -x509 -new -key ca-key.pem -out ca.pem -nodes -sha256 -days 3650 -subj "/O=Docker CE" -extensions docker_ca -config <( cat `openssl version -d | sed 's,^.*"\(.*\)",\1/openssl.cnf,'`; echo "
[docker_ca]
keyUsage = critical, keyCertSign, digitalSignature, keyEncipherment, keyAgreement
basicConstraints = critical, CA:true
" )
openssl x509 -text -noout -in ca.pem > ca.txt


# create server certificate
[ -s server-key.pem ] || openssl genrsa -out server-key.pem
openssl req -new -key server-key.pem -out server.csr -nodes -sha256 -subj "/O=Docker CE/CN=docker-machine"

openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem -sha256 -days 3650 -extfile <( echo "
keyUsage = critical, digitalSignature, keyEncipherment, keyAgreement
extendedKeyUsage = serverAuth
basicConstraints = critical, CA:FALSE
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.lvh.me
DNS.3 = [::1]
IP.1 = 127.0.0.1
IP.2 = fe80::1
IP.3 = 192.168.139.128
" )
openssl x509 -text -noout -in server.pem > server.txt


# create client certificate
[ -s key.pem ] || openssl genrsa -out key.pem
openssl req -new -key key.pem -out client.csr -nodes -subj "/O=Docker CE/CN=docker-bootstrap"

openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -days 3650 -extfile <( echo "
keyUsage = critical, digitalSignature
extendedKeyUsage = clientAuth
basicConstraints = critical, CA:FALSE
" )
openssl x509 -text -noout -in cert.pem > cert.txt


# generate SSH key
[ -s id_rsa ] || ssh-keygen -t rsa -C "docker@lvh.me" -f id_rsa -q -N "" || true


# cleanup
[ -s certificates.tgz ] || tar --remove-files -czf certificates.tgz *.pem id_rsa* || true
rm -f *.srl *.csr
