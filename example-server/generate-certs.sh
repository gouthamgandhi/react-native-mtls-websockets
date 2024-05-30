#!/bin/bash

# Set the directories for output files
mkdir -p certs
cd certs || exit

# Step 1: Generate the CA's private key and certificate
echo "Generating CA's private key..."
openssl genrsa -out ca.key 4096

echo "Generating CA's certificate..."
openssl req -x509 -new -nodes -key ca.key -sha256 -days 1024 -out ca.crt -subj "/C=IN/ST=Telangana/L=Hyderabad/O=Futuristic Labs Private Limited/OU=Semi/CN=semi.futuristiclabs.com"

# Step 2: Generate the Server's private key and certificate
echo "Generating Server's private key..."
openssl genrsa -out server.key 2048

echo "Generating Server's certificate signing request..."
openssl req -new -key server.key -out server.csr -subj "/C=IN/ST=Telangana/L=Hyderabad/O=Futuristic Labs Private Limited/OU=Semi/CN=server.semi.futuristiclabs.com"

echo "Signing Server's certificate with CA's key..."
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 500 -sha256

# Step 3: Generate the Client's private key and certificate
echo "Generating Client's private key..."
openssl genrsa -out client.key 2048

echo "Generating Client's certificate signing request..."
openssl req -new -key client.key -out client.csr -subj "/C=IN/ST=Telangana/L=Hyderabad/O=Futuristic Labs Private Limited/OU=Semi/CN=client.semi.futuristiclabs.com"

echo "Signing Client's certificate with CA's key..."
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 500 -sha256

# Step 4: Generate the .p12 file for the client
echo "Generating .p12 file for the client..."
openssl pkcs12 -export -out client.p12 -inkey client.key -in client.crt -certfile ca.crt -password pass:test -legacy

echo "Process completed. Check the 'certs' folder."
