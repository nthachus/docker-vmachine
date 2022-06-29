@ECHO OFF
SetLocal

REM OpenSSL config file
COPY /Y "%~dp0docker-ssl.cnf" "%TEMP%"
SET "_SSL_CONF=%TEMP%\docker-ssl.cnf"

SET "_IP_ARG=%~1"
IF "%_IP_ARG%"=="" (
    FOR /F "skip=2 tokens=2*" %%H IN (
        'REG QUERY "HKLM\SOFTWARE\VMware, Inc.\VMnetLib\VMnetConfig\vmnet8" /v IPSubnetAddress /reg:32'
    ) DO SET "_IP_ARG=%%~nI.128"
)
ECHO IP.3 = %_IP_ARG%>> "%_SSL_CONF%"

REM Create self-signed CA
REM openssl genrsa -des3 -out ca-key.pem
IF NOT EXIST ca-key.pem openssl genrsa -out ca-key.pem

openssl req -x509 -new -key ca-key.pem -out ca.pem -nodes -sha256 -days 3650 -subj "/O=Docker CE" -config "%_SSL_CONF%"
openssl x509 -text -noout -in ca.pem > ca.txt

REM Create server certificate
IF NOT EXIST server-key.pem openssl genrsa -out server-key.pem
openssl req -new -key server-key.pem -out server.csr -nodes -sha256 -subj "/O=Docker CE/CN=docker-machine" ^
    -config "%_SSL_CONF%"

openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem -sha256 -days 3650 ^
    -extfile "%_SSL_CONF%" -extensions server_ext
openssl x509 -text -noout -in server.pem > server.txt

REM Create client certificate
IF NOT EXIST key.pem openssl genrsa -out key.pem
openssl req -new -key key.pem -out client.csr -nodes -subj "/O=Docker CE/CN=docker-bootstrap" -config "%_SSL_CONF%"

openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -days 3650 ^
    -extfile "%_SSL_CONF%" -extensions client_ext
openssl x509 -text -noout -in cert.pem > cert.txt

REM Generate SSH key
IF NOT EXIST id_rsa ssh-keygen -t rsa -b 2048 -q -C "docker@lvh.me" -N "" -f id_rsa

REM Cleanup
IF NOT EXIST certificates.tgz (
    WHERE tar >NUL 2>&1 && (
        tar -czf certificates.tgz *.pem id_rsa* & DEL /F /Q *.pem id_rsa*
    ) || (
        SET _7Z_EXEC=7za
        FOR /F "skip=2 tokens=2*" %%H IN ('REG QUERY "HKCU\Software\7-Zip" /v Path') DO SET "_7Z_EXEC=%%~dpI7z"

        "%_7Z_EXEC%" a -ttar -so -an -sdel *.pem id_rsa* | "%_7Z_EXEC%" a -si certificates.tgz
    )
)
DEL /F /Q *.srl *.csr
