const express = require('express');
const https = require('https');
const fs = require('fs');
const path = require('path');

const app = express();

// Middleware to log successful connections
app.use((req, res, next) => {
  console.log(
    `Client connected - IP: ${req.ip} Method: ${req.method} URL: ${req.originalUrl}`,
  );
  next();
});

app.get('/', (req, res) => {
  res.send('Hello, HTTPS world!');
});

const options = {
  key: fs.readFileSync(path.join(__dirname, './certs/server.key')),
  cert: fs.readFileSync(path.join(__dirname, './certs/server.crt')),
};

const server = https.createServer(options, app);

server.listen(8443, () => {
  console.log('HTTPS server listening on port 8443');
});

// Listening for tlsClientError event
server.on('tlsClientError', (error, socket) => {
  console.error(`TLS Client Error: ${error.message}`);
  console.log(`Client IP: ${socket.remoteAddress}`);
  console.log(
    `Socket details: ${JSON.stringify(
      {address: socket.address(), authorized: socket.authorized},
      null,
      2,
    )}`,
  );
});
