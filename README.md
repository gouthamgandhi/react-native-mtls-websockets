# mTLS Example Project

This project is an example project that showcases mTLS communication with a WebSocket server in a React Native application. The project contains a test server and client that can be used to test the mTLS communication.

What is mTLS?

mTLS (mutual Transport Layer Security) is a security protocol that uses certificates to authenticate both the client and the server in a communication. In mTLS, the client and server exchange certificates to authenticate each other before establishing a secure connection.

The `WebSocket` module available in React Native does not support mTLS out of the box, so we have created a react native bridge module which implements native mTLS Websockets to the support mTLS WebSocket communication in a React Native application.

Important Files:

- ios/WebsocketsModule.swift
- ios/WebsocketsModule.m
- App.js

# Test Server and Client

The project contains a test server and client that can be used to test the mTLS communication.

## Test Server

- folder: `example-server`
- file: `test-server.js`

The test server is a WebSocket server that listens on port `8083` and requires mTLS communication. The server uses the certificates in the `certs` folder to authenticate the client.

```bash
cd example-server
node test-server.js
```

## Test Client

Folder: `example-server`
File: `test-client.js`

The test client is a WebSocket client that connects to the test server. The client uses the certificates in the `certs` folder to authenticate itself to the server.

```bash
cd example-server
node test-client.js
```

Note: You need to update the `test-client.js` file with the correct path to the certificates and the server URL if you are running the server on a different machine or port.

# Generating Certificates

The `certs` folder contains the certificates that are used by the server and client to authenticate each other. The certificates are generated using the `openssl` command-line tool.

## Generate Root CA

```bash
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt
```

# Convert your ca.crt to der format

You need the ca.crt in der format to use it in the iOS project.

```bash
openssl x509 -outform der -in ca.crt -out ca.der
```

## Generate Server Certificate & Sign with Root CA

```bash
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256
```

## Generate Client Certificate & Sign with Root CA

```bash
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256
```

# PKCS12 Format for IOS

To use the certificates in an iOS application, you need to convert them to PKCS12 format.

## Convert Client Certificate to PKCS12

```bash
openssl pkcs12 -export -out client.p12 -inkey client.key
-in client.crt -certfile ca.crt
```

# Adding Certificates to the iOS Project

To use the certificates in the iOS project, you need to add them to the project and make them available to the WebSocket module.

- Drop the p12 file in the ios folder of the project.
- Add the p12 file to the Xcode project.
- Update the `WebsocketsModule.swift` file with the correct path to the p12 file.
- Add them to the Build Phases -> Copy Bundle Resources.

- Since we are using self signed certificates, we need to add the CA certificate to the iOS project.
- Add the CA certificate in the `ca.der` format to the Xcode project.
  - Drag and drop the `ca.der` file into your simulator.
  - Email your CA certificate to yourself and double click it on your iOS device.
  - Navigate to VPN & Device Management -> Certificates, Identifiers & Profiles -> Identifiers -> App IDs -> Your App ID -> Edit -> Push Notifications -> Configure -> Add the CA certificate.

# How to test

Start the server and edit the App.js file with the correct server URL and certificates path.

If there is a successful connection, you will see the message "Hello Server" in the console.
