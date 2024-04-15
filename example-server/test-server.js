const https = require('https');
const fs = require('fs');
const WebSocket = require('ws');

const server = https.createServer({
  cert: fs.readFileSync('./certs/server.crt'),
  key: fs.readFileSync('./certs/server.key'),
  ca: fs.readFileSync('./certs/ca.crt'),
  minVersion: 'TLSv1.2',
  maxVersion: 'TLSv1.3',
  requestCert: true,
  rejectUnauthorized: false, // This ensures that the client certificate is required and must be signed by the CA
});

const wss = new WebSocket.Server({noServer: true});

wss.on('connection', function connection(ws) {
  // print socket information
  console.log('Client IP:', ws._socket.remoteAddress);
  ws.on('message', function incoming(message) {
    console.log('received: %s', message);
  });

  ws.send('something' + Date.now().toLocaleString());
});

server.on('upgrade', function upgrade(request, socket, head) {
  // This function is not defined on purpose. Implement your own validation.
  const verifyClient = (info, done) => {
    // Implement validation logic here
    console.log('Client certificate:', info.socket.getPeerCertificate());
    done(true); // Proceed with the connection if valid
  };

  verifyClient(request, verified => {
    if (verified) {
      wss.handleUpgrade(request, socket, head, function done(ws) {
        wss.emit('connection', ws, request);
      });
    } else {
      socket.destroy();
    }
  });
});

server.on('tlsClientError', (error, tlsSocket) => {
  console.error('A TLS client error occurred:', error.message);
  // You can get more information from `tlsSocket`, like the remote address
  console.log('Client IP:', tlsSocket.remoteAddress);
});

server.listen(8083, () => {
  console.log('WSS Listening on https://localhost:8083');
});

// HTTPS Server for Testing
const httpsServer = https.createServer(
  {
    minVersion: 'TLSv1.2',
    maxVersion: 'TLSv1.3',
    cert: fs.readFileSync('./certs/server.crt'),
    key: fs.readFileSync('./certs/server.key'),
    ca: fs.readFileSync('./certs/ca.crt'),
  },
  (req, res) => {
    console.log('Client IP:', req.connection.remoteAddress);
    res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('This is an HTTPS server without certs for testing.\n');
  },
);

httpsServer.listen(8082, () => {
  console.log('HTTPS server without certs listening on http://localhost:8082');
});

httpsServer.on('tlsClientError', (error, tlsSocket) => {
  console.error('A TLS client error occurred:', error.message);
  // You can get more information from `tlsSocket`, like the remote address
  console.log('Client IP:', tlsSocket.remoteAddress);
});
