import ssl
import eventlet
eventlet.monkey_patch()

from flask import Flask
from flask_socketio import SocketIO

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

@app.route('/')
def index():
    return 'This server supports WSS with mTLS.'

@socketio.on('connect')
def test_connect():
    print("Client connected")
    return True

@socketio.on('disconnect')
def test_disconnect():
    print('Client disconnected')

if __name__ == '__main__':
    # Create an SSL context for mTLS using Python's built-in ssl module
    ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ssl_context.load_cert_chain(certfile='server.crt', keyfile='server.key')  # Load the server certificate and private key
    ssl_context.load_verify_locations('ca.crt')  # Specify the CA certificate that issued the client certs
    ssl_context.verify_mode = ssl.CERT_REQUIRED  # Force the server to require and verify client certificates
    
    # Use eventlet to listen on the specified port with the created SSL context
    listener = eventlet.listen(('0.0.0.0', 5001))
    secure_socket = eventlet.wrap_ssl(listener, certfile='server.crt', keyfile='server.key', server_side=True, ca_certs='ca.crt', cert_reqs=ssl.CERT_REQUIRED)

    # Run the application with the secured socket
    socketio.run(app=app, host='0.0.0.0', port=5001, keyfile='server.key', certfile='server.crt', ssl_context=ssl_context)