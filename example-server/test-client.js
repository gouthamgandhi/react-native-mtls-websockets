const fs = require('fs');
const WebSocket = require('ws');

// const client = new WebSocket('wss://localhost:8083/semictrl', {
//   cert: fs.readFileSync('./certs/client.crt'),
//   key: fs.readFileSync('./certs/client.key'),
//   ca: fs.readFileSync('./certs/ca.crt'),
//   // minVersion: 'TLSv1.1',
//   // maxVersion: 'TLSv1.3',
//   rejectUnauthorized: false, // This ensures the server certificate is signed by the known CA
// });

// const client = new WebSocket('wss://192.168.0.114/semictrl', {
//   cert: fs.readFileSync('./certs/client.crt'),
//   key: fs.readFileSync('./certs/client.key'),
//   ca: fs.readFileSync('./certs/ca.crt'),
//   // minVersion: 'TLSv1.1',
//   // maxVersion: 'TLSv1.3',
//   rejectUnauthorized: false, // This ensures the server certificate is signed by the known CA
// });

const client = new WebSocket('wss://192.168.1.4/semictrl', {
  cert: fs.readFileSync('./certs/semi/oldsemiclientcrt.crt'),
  key: fs.readFileSync('./certs/semi/oldsemiclientkey.key'),
  ca: fs.readFileSync('./certs/semi/oldsemicacert.crt'),
  // minVersion: 'TLSv1.1',
  // maxVersion: 'TLSv1.3',
  rejectUnauthorized: false, // This ensures the server certificate is signed by the known CA
});

client.on('open', function open() {
  console.log('connected');
  // client.send('Hello Server!');
  // setTimeout(() => {
  //   client.send(JSON.stringify({CMD: 'GET-SEMI-STATUS'}));
  //   // client.send(JSON.stringify({CMD: 'IND-GET-VALS-PER'}));
  // }, 1000);
});

client.on('message', function incoming(data) {
  console.log(data.toString());
});

// On close
client.on('close', function close() {
  console.log('disconnected');
});

// Handle TLS errors

client.on('tlsClientError', (error, tlsSocket) => {
  console.error('A TLS client error occurred:', error.message);
  // You can get more information from `tlsSocket`, like the remote address
  console.log('Client IP:', tlsSocket.remoteAddress);
});

client.on('error', function error(err) {
  console.error(err);
});

// while (1) {
//   if (client.readyState === WebSocket.OPEN) {
//     client.send(JSON.stringify({CMD: 'GET-SEMI-STATUS'}));
//   }
// }
