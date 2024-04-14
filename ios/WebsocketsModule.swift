// Read 
// https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/OverridingSSLChainValidationCorrectly.html#//apple_ref/doc/uid/TP40012544
// https://developer.apple.com/documentation/security/certificate_key_and_trust_services/identities/importing_an_identity
// https://developer.apple.com/documentation/security/certificate_key_and_trust_services/certificates/getting_a_certificate
// https://developer.apple.com/documentation/security/certificate_key_and_trust_services/trust/creating_a_trust_object

import Foundation
import Network
import Security

@objc(MTLSWebSocketModule)
class MTLSWebSocketModule: RCTEventEmitter, URLSessionWebSocketDelegate, URLSessionDelegate {
    
    var webSocketTask: URLSessionWebSocketTask?
    var urlSession: URLSession!
    
    override init() {
        super.init()
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    override func supportedEvents() -> [String]! {
        return ["onMessage", "onError", "onConnectionOpen", "onConnectionClosed"]
    }
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc 
    func connect(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            self.sendEvent(withName: "onError", body: "Invalid URL")
            return
        }
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        listenForMessages()
    }
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                self?.sendEvent(withName: "onError", body: error.localizedDescription)
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.sendEvent(withName: "onMessage", body: text)
                case .data(let data):
                    // Handle data message if necessary
                    break
                @unknown default:
                    fatalError()
                }
                
                // Continue listening for messages
                self?.listenForMessages()
            }
        }
    }
    
    @objc func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        self.sendEvent(withName: "onConnectionClosed", body: nil)
    }
    
    @objc func sendMessage(_ message: String) {
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                self.sendEvent(withName: "onError", body: error.localizedDescription)
            }
        }
    }

    // URLSessionDelegate Methods
    // https://developer.apple.com/documentation/foundation/url_loading_system/handling_an_authentication_challenge
    // https://stackoverflow.com/questions/21537203/ios-nsurlauthenticationmethodclientcertificate-not-requested-vs-activesync-serve
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodClientCertificate:
            // Respond to the server's request for a client certificate.
            guard let identity = extractIdentity(), let certificate = extractCertificate(identity: identity) else {
                // print identity and certificate                
                completionHandler(.cancelAuthenticationChallenge, nil)
                self.sendEvent(withName: "onError", body: "Failed to extract client certificate")
                return
            }
            let credential = URLCredential(identity: identity, certificates: [certificate], persistence: .forSession)
            completionHandler(.useCredential, credential)
            
        case NSURLAuthenticationMethodServerTrust:
            // Validate the server's certificate including self-signed ones.
            if let serverTrust = challenge.protectionSpace.serverTrust, evaluateServerTrust(trust: serverTrust, against: ["rootCA"]) {
                self.sendEvent(withName: "onError", body: "Server trust validated successfully")
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                self.sendEvent(withName: "onError", body: "Failed to validate server trust")
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
            
        default:
            self.sendEvent(withName: "onError", body: "Unknown authentication method")
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    // mTLS Support 

    // Importing an Identity
    // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/identities/importing_an_identity
     private func extractIdentity() -> SecIdentity? {
      guard let path = Bundle.main.path(forResource: "client", ofType: "p12"),
            let p12Data = NSData(contentsOfFile: path) else {
                self.sendEvent(withName: "onError", body: "Failed to load p12 file")              
                return nil
                }
       
      let key: NSString = kSecImportExportPassphrase as NSString
       let password = "test"
       let options = [ kSecImportExportPassphrase as String: password ]
//      let options: NSDictionary = [key: "test"]
      var rawItems: CFArray?
    //   print password and options to see if they are correct
//        print("password: \(password)")
        print("options: \(options)")
      let secError: OSStatus = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)
      guard secError == errSecSuccess else {
            let errorString = SecCopyErrorMessageString(secError, nil) as String? ?? "Unknown error"
            self.sendEvent(withName: "onError", body: "SecPKCS12Import failed: \(errorString)")
            return nil 
        }

      if let items = rawItems as? Array<Dictionary<String, AnyObject>>,
         let firstItem = items.first,
         let identity = firstItem[kSecImportItemIdentity as String] as! SecIdentity? {
            // Log identity
            print("Identity: \(identity)")
            return identity
        }
        // let trust = firstItem[kSecImportItemTrust as String] as! SecTrust?
   
      return nil
  }
    
    private func extractCertificate(identity: SecIdentity) -> SecCertificate? {
        // Extract the certificate from the identity.
        var certificate: SecCertificate?
        SecIdentityCopyCertificate(identity, &certificate)
        return certificate
    }
    
    private func evaluateServerTrust(trust: SecTrust, against trustedCertNames: [String]) -> Bool {
        let policy = SecPolicyCreateBasicX509()
        SecTrustSetPolicies(trust, policy)
        
        for certName in trustedCertNames {
            if let certPath = Bundle.main.path(forResource: certName, ofType: "cer"),
               let certData = NSData(contentsOfFile: certPath),
               let cert = SecCertificateCreateWithData(nil, certData) {
                SecTrustSetAnchorCertificates(trust, [cert] as CFArray)
            }
        }
        
        SecTrustSetAnchorCertificatesOnly(trust, false) // false allows system roots to also be trusted
        
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(trust, &result)
        return status == errSecSuccess && (result == .proceed || result == .unspecified)
    }
    
    // Add more methods as needed for WebSocket communication (e.g., sendMessage)
}
