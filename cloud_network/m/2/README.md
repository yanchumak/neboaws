### Create a Certificate Authority (CA)

```shell
# Create a directory for the CA
mkdir -p ~/myvpn-ca
cd ~/myvpn-ca

# Generate a private key for the CA
openssl genpkey -algorithm RSA -out ca-key.pem

# Create a self-signed CA certificate
openssl req -x509 -new -nodes -key ca-key.pem -sha256 -days 365 -out ca-cert.pem \
-subj "/C=US/ST=California/L=San Francisco/O=MyCompany/OU=IT/CN=myvpn-ca"
```

### Generate Server Certificate

```shell
# Generate a private key for the server
openssl genpkey -algorithm RSA -out server-key.pem

cat > server.cnf <<EOF
[ req ]
default_bits       = 2048
default_md         = sha256
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
countryName                = Country Name (2 letter code)
countryName_default        = US
stateOrProvinceName        = State or Province Name (full name)
stateOrProvinceName_default = California
localityName               = Locality Name (eg, city)
localityName_default       = San Francisco
organizationName           = Organization Name (eg, company)
organizationName_default   = MyCompany
organizationalUnitName     = Organizational Unit Name (eg, section)
organizationalUnitName_default = IT
commonName                 = Common Name (e.g. server FQDN or YOUR name)
commonName_max             = 64
commonName_default         = vpn.example.com

[ req_ext ]
subjectAltName = @alt_names
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ alt_names ]
DNS.1   = vpn.example.com
EOF

openssl req -new -key server-key.pem -out server-req.pem -config server.cnf

openssl x509 -req -in server-req.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
-out server-cert.pem -days 365 -sha256 -extfile server.cnf -extensions req_ext

```

### Generate Client Certificate
```shell
# Generate a private key for the client
openssl genpkey -algorithm RSA -out client-key.pem

cat > client.cnf <<EOF
[ req ]
default_bits       = 2048
default_md         = sha256
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
countryName                = Country Name (2 letter code)
countryName_default        = US
stateOrProvinceName        = State or Province Name (full name)
stateOrProvinceName_default = California
localityName               = Locality Name (eg, city)
localityName_default       = San Francisco
organizationName           = Organization Name (eg, company)
organizationName_default   = MyCompany
organizationalUnitName     = Organizational Unit Name (eg, section)
organizationalUnitName_default = IT
commonName                 = Common Name (e.g. server FQDN or YOUR name)
commonName_max             = 64
commonName_default         = myvpn-client

[ req_ext ]
keyUsage = critical, digitalSignature
extendedKeyUsage = clientAuth
EOF

openssl req -new -key client-key.pem -out client-req.pem -config client.cnf

openssl x509 -req -in client-req.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
-out client-cert.pem -days 365 -sha256 -extfile client.cnf -extensions req_ext
```
