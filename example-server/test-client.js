const fs = require('fs');
const WebSocket = require('ws');

// const client = new WebSocket('wss://192.168.68.104/semictrl', {
//   cert: fs.readFileSync('./certs/client.crt'),
//   key: fs.readFileSync('./certs/client.key'),
//   ca: fs.readFileSync('./certs/ca.crt'),
//   // minVersion: 'TLSv1.1',
//   // maxVersion: 'TLSv1.3',
//   rejectUnauthorized: false, // This ensures the server certificate is signed by the known CA
// });

const client = new WebSocket('wss://localhost:8083', {
  cert: fs.readFileSync('./certs/client.crt'),
  key: fs.readFileSync('./certs/client.key'),
  ca: fs.readFileSync('./certs/ca.crt'),
  // minVersion: 'TLSv1.1',
  // maxVersion: 'TLSv1.3',
  rejectUnauthorized: false, // This ensures the server certificate is signed by the known CA
});

// const client = new WebSocket('wss://192.168.68.143/semictrl', {
//   cert: fs.readFileSync('./certs/semi/clientcrt.crt'),
//   key: fs.readFileSync('./certs/semi/clientkey.key'),
//   ca: fs.readFileSync('./certs/semi/cacert.crt'),
//   minVersion: 'TLSv1.1',
//   maxVersion: 'TLSv1.3',
//   rejectUnauthorized: false, // This ensures the server certificate is signed by the known CA
// });

client.on('open', function open() {
  console.log('connected');
  client.send('Hello Server!');
});

client.on('message', function incoming(data) {
  console.log(data.toString());
});
