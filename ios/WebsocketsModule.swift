//
//  MTLSWebSocket.swift
//  klynkApp
//
//  Created by Goutham Gandhi Nadendla on 17/04/24.
//

// Read 
// https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/OverridingSSLChainValidationCorrectly.html#//apple_ref/doc/uid/TP40012544
// https://developer.apple.com/documentation/security/certificate_key_and_trust_services/identities/importing_an_identity
// https://developer.apple.com/documentation/security/certificate_key_and_trust_services/certificates/getting_a_certificate
// https://developer.apple.com/documentation/security/certificate_key_and_trust_services/trust/creating_a_trust_object

// URLSessionDelegate Methods
// https://developer.apple.com/documentation/foundation/url_loading_system/handling_an_authentication_challenge
// https://stackoverflow.com/questions/21537203/ios-nsurlauthenticationmethodclientcertificate-not-requested-vs-activesync-serve

// mTLS Support 
// Importing an Identity
// https://developer.apple.com/documentation/security/certificate_key_and_trust_services/identities/importing_an_identity

import Foundation
import Network
import Security

@objc(MTLSWebSocket)
class MTLSWebSocket: RCTEventEmitter, URLSessionWebSocketDelegate, URLSessionDelegate {
    
    // MARK: - Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false

    private var updateWebSocketTask: URLSessionWebSocketTask?
    private var isUpdateConnected = false

    private var urlSession: URLSession!
    private var queue = DispatchQueue(label: "com.futuristiclabs.websocket")
    private var messageQueue = DispatchQueue(label: "com.futuristiclabs.messagequeue")
    private var messageBuffer: [String] = []
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 60
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }
    
    // MARK: - RCTEventEmitter
    
    override func supportedEvents() -> [String]! {
        return ["onMessage", "onError", "onConnection", "onClosed", "onWebSocketError" , "onUpdateMessage", "onUpdateError", "onUpdateConnection", "onUpdateClosed", "onUpdateWebSocketError", "onUpdateFailure", "onTotalPages", "firmwareVersion", "onOTAStatus"]
    }
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    // MARK: - Public Methods
    
    @objc
    func connect(_ urlString: String , update: Bool) {
        print("Native Side Connecting: \(urlString)")
        guard let url = URL(string: urlString) else {
            self.sendEvent(withName: "onError", body: ["status": "WEB_SOCKET_ERROR", "message": "Invalid URL"])
            return
        }

        // Update Connection
        if update {
            updateWebSocketTask = urlSession.webSocketTask(with: url)
            updateWebSocketTask?.resume()
            self.sendEvent(withName: "onUpdateConnection", body: ["status": "CONNECTED"])
            isUpdateConnected = true
            receiveUpdateMessages()
            return
        }
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume() 

        self.sendEvent(withName: "onConnection", body: ["status": "CONNECTED"])   
        isConnected = true
        receiveMessages()

    }
    
    @objc
    func disconnect(_ update: Bool) {

        // Close Update Connection
        if update {
            updateWebSocketTask?.cancel(with: .goingAway, reason: nil)
            isUpdateConnected = false
            self.sendEvent(withName: "onUpdateClosed", body: ["status": "CLOSED"])
            return
        }

        // Close Standard client Connection
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
        self.sendEvent(withName: "onClosed", body: ["status": "CLOSED"])
    }
    
    @objc
    func sendMessage(_ message: String) {
        print("Native Side Sending Message: \(message)")
        guard isConnected else {
            self.sendEvent(withName: "onError", body:[ "status": "WEB_SOCKET_ERROR", "message":"WebSocket is not connected"])
            return
        }
        
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                self.sendEvent(withName: "onError", body: ["status": "WEB_SOCKET_ERROR", "message": error.localizedDescription])
            }
        }
    }
    
    // Connection Status
    @objc
    func isClientConnected(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        resolve(isConnected)
    }
    
    // Update Connection Status
    @objc
    func isUpdateClientConnected(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        resolve(isUpdateClientConnected)
    }

    // MARK: - Private Methods
    
    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                self?.sendEvent(withName: "onError", body:[ "status": "WEB_SOCKET_ERROR", "message": error.localizedDescription])
            case .success(let message):
                switch message {
                case .string(let text):
                    // self?.sendEvent(withName: "onMessage", body: ["message": text])
                    // Convert the message to JSON format
                    if let jsonData = try? JSONSerialization.data(withJSONObject: ["message": text], options: []) {
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            self?.sendEvent(withName: "onMessage", body: jsonString)
                        }
                    }
                    
                    self?.handleIncomingMessage(text)
                case .data(let data):
                    // Handle data message if necessary
                    self?.sendEvent(withName: "onMessage", body:["message": data])
                    break
                @unknown default:
                    fatalError()
                }
                
                // Continue listening for messages
                self?.receiveMessages()
            }
        }
    }

    private func receiveUpdateMessages() {
        updateWebSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                self?.sendEvent(withName: "onUpdateError", body:[ "status": "WEB_SOCKET_ERROR", "message": error.localizedDescription])
            case .success(let message):
                switch message {
                case .string(let text):
                    // self?.sendEvent(withName: "onMessage", body: ["message": text])
                    // Convert the message to JSON format
                    if let jsonData = try? JSONSerialization.data(withJSONObject: ["message": text], options: []) {
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            self?.sendEvent(withName: "onUpdateMessage", body: jsonString)
                        }
                    }
                    
                    self?.handleIncomingMessage(text)
                case .data(let data):
                    // Handle data message if necessary
                    self?.sendEvent(withName: "onUpdateMessage", body:["message": data])
                    break
                @unknown default:
                    fatalError()
                }
                
                // Continue listening for messages
                self?.receiveUpdateMessages()
            }
        }
    }
    
    private func handleIncomingMessage(_ message: String) {
        messageQueue.async {
            self.messageBuffer.append(message)
            self.processMessageBuffer()
        }
    }
    
    private func processMessageBuffer() {
        while !messageBuffer.isEmpty {
            let message = messageBuffer.removeFirst()
            // self.sendEvent(withName: "onMessage", body: ["message": message])
            
            if let command = parseCommand(from: message) {
                switch command {
                case "IND-DATA":
                    break // Handle incoming data as needed
                case "OTA-WRITE-PAGE":
                    handleOTAWritePage(message)
                case "GET-OTA-STATUS":
                    handleonOTAStatus(message)
                case "GET-RUN-FW-VER":
                    handleFirmwareVersion(message)
                default:
                    break // Handle other commands as needed
                }
            }
        }
    }
    
    private func parseCommand(from message: String) -> String? {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let jsonDict = json as? [String: Any],
              let command = jsonDict["CMD"] as? String else {
            return nil
        }
        return command
    }
    
    // MARK: - URLSessionDelegate
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodClientCertificate:
            print("Handing client cert authentication")
            guard let identity = extractIdentity(), let certificate = extractCertificate(identity: identity) else {
                print("Failed to extract client identity and certificate")
                completionHandler(.cancelAuthenticationChallenge, nil)
                self.sendEvent(withName: "onError", body: ["status": "WEB_SOCKET_ERROR", "message": "Failed to extract client certificate"])
                return
            }
            print("Client identity and certificate extracted succesfully")
            let credential = URLCredential(identity: identity, certificates: [certificate], persistence: .forSession)
            completionHandler(.useCredential, credential)
            
        case NSURLAuthenticationMethodServerTrust:
            print("Handling Server Trust Authentication")
            if let serverTrust = challenge.protectionSpace.serverTrust, evaluateServerTrust(trust: serverTrust, against: ["oldsemicacrt"]) {
                print("Server Trust is valid")
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                self.sendEvent(withName: "onError", body: ["status": "WEB_SOCKET_ERROR", "message":"Failed to validate server trust"])
                print("Server trust is in-valid")
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
            
        default:
            self.sendEvent(withName: "onError", body: ["status": "WEB_SOCKET_ERROR", "message": "Unknown authentication method"])
            print("Received an unknown authentication method challenge.")
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    // MARK: - mTLS Support
    
//    private func extractIdentity() -> SecIdentity? {
//        guard let path = Bundle.main.path(forResource: "client", ofType: "p12"),
//              let p12Data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
//            sendEvent(withName: "onError", body: "Failed to load p12 file")
//            return nil
//        }
//        
//        let options: [String: Any] = [kSecImportExportPassphrase as String: "test"]
//        var items: CFArray?
//        
//        let secError: OSStatus = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)
//        guard secError == errSecSuccess, let items = items as? Array<Dictionary<String, Any>>,
//              let firstItem = items.first,
//              let identity = firstItem[kSecImportItemIdentity as String] as? SecIdentity else {
//            let errorString = SecCopyErrorMessageString(secError, nil) as String? ?? "Unknown error"
//            sendEvent(withName: "onError", body: "SecPKCS12Import failed: \(errorString)")
//            return nil
//        }
//
//        return identity
//    }  

    private func extractIdentity() -> SecIdentity? {
        guard let path = Bundle.main.path(forResource: "oldsemiclientp12", ofType: "p12"),
            let p12Data = NSData(contentsOfFile: path) else {
                self.sendEvent(withName: "onError", body: "Failed to load p12 file")              
                return nil
            }
       
        let key: NSString = kSecImportExportPassphrase as NSString
        let password = "test"
        let options = [ kSecImportExportPassphrase as String: password ]
        // let options: NSDictionary = [key: "test"]
        var rawItems: CFArray?
        // print password and options to see if they are correct
        // print("password: \(password)")
        print("options: \(options)")
        let secError: OSStatus = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)
        guard secError == errSecSuccess else {
            let errorString = SecCopyErrorMessageString(secError, nil) as String? ?? "Unknown error"
            self.sendEvent(withName: "onError", body: ["status": "WEB_SOCKET_ERROR", "message": "SecPKCS12Import failed: \(errorString)"])
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
        var certificate: SecCertificate?
        SecIdentityCopyCertificate(identity, &certificate)
        return certificate
    }
    
    private func evaluateServerTrust(trust: SecTrust, against trustedCertNames: [String]) -> Bool {
        print("Server Trust evaluation in progress ...")
        let policy = SecPolicyCreateBasicX509()
        SecTrustSetPolicies(trust, policy)
        
        // Load the expected certificate from the app bundle
        guard let certPath = Bundle.main.path(forResource: "oldsemicacrt", ofType: "der"),
            let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)),
            // Accepts DER format Certificte 
            let cert = SecCertificateCreateWithData(nil, certData as CFData) else {
                print("Error: Unable to load certificate from the provided path.")
                if let bundlePath = Bundle.main.resourcePath {
                    let resourceContents = try? FileManager.default.contentsOfDirectory(atPath: bundlePath)
                    print("Bundle contents: \(resourceContents ?? [])")
                }
              return false
        }


        
        // Set the loaded certificate as the anchor certificate
        SecTrustSetAnchorCertificates(trust, [cert] as CFArray)
      
        // Disable automatic trust evaluation to use the provided certificate only
        SecTrustSetAnchorCertificatesOnly(trust, true)

        var error: CFError?
        let result = SecTrustEvaluateWithError(trust, &error)
      
        if let error = error {
            let errorDesc = CFErrorCopyDescription(error) as String
            let errorCode = CFErrorGetCode(error)  // CFIndex
         
            print("Trust evaluation failed with error: \(errorDesc)")
            // Example generic error handling
            print("Error code: \(errorCode)")
            // Optionally, handle specific error codes if relevant
            // handleSpecificErrorCodes(errorCode)
        }
      
        // var result = SecTrustResultType.invalid
        // let status = SecTrustEvaluate(trust, &result)
        // return status == errSecSuccess && (result == .proceed || result == .unspecified)
      
          return result
    }

// MARK: - Additional Functionality
    
//  @objc
//  func isClientConnected(_: _) -> Bool {
//      return isConnected
//  }

//  @objc
//  func isUpdateClientConnected(_: _) -> Bool {
//      return isUpdateConnected
//  }


    @objc
    func checkFile(_ fileName: String) -> Bool {
        guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return false
        }
        let filePath = URL(fileURLWithPath: path).appendingPathComponent(fileName).path
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    @objc
    func startOTAUpdate(_ fileName: String) {
        guard checkFile(fileName) else {
            sendEvent(withName: "onError", body: ["status": "WEB_SOCKET_ERROR", "message": "File not found: \(fileName)"])
            return
        }
        
        checkonOTAStatus { [weak self] status in
            guard let self = self else { return }
            
            switch status {
            case "IN-PROGRESS":
                self.sendOTAAbort()
            case "IDLE":
                self.initiateOTAUpdate(fileName)
            case "OK":
                self.initiateOTAUpdate(fileName)
            default:
                self.sendEvent(withName: "onError", body: ["status": "WEB_SOCKET_ERROR", "message": "Invalid OTA status: \(status)"])
            }
        }
    }
    
    private func checkonOTAStatus(completion: @escaping (String) -> Void) {
        let command = ["CMD": "GET-OTA-STATUS"]

        // let command = ["CMD": "OTA-READY"]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: command, options: []) else {
            completion("UNKNOWN")
            return
        }
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion("UNKNOWN")
            return
        }
        
        sendMessage(jsonString)
        
        // Wait for the response from the device
        let semaphore = DispatchSemaphore(value: 0)
        var status = "UNKNOWN"
        
        let handler: (String) -> Void = { message in
            if let command = self.parseCommand(from: message),
               command == "GET-OTA-STATUS",
            //    command == "OTA-READY",
               let jsonData = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData, options: []),
               let jsonDict = json as? [String: Any],
               let statusValue = jsonDict["STATUS"] as? String {
                status = statusValue
            }            
            semaphore.signal()
        }
        
        messageQueue.async {
            self.messageBuffer.append(contentsOf: self.messageBuffer.filter { message in
                guard let command = self.parseCommand(from: message) else {
                    return false
                }
                return command != "GET-OTA-STATUS"
                // return command != "OTA-READY"
            })
            self.processMessageBuffer()
        }
        
        DispatchQueue.global().async {
            semaphore.wait()
            completion(status)
        }
    }
    
    private func sendOTAAbort() {
        let command = ["CMD": "OTA-ABORT"]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: command, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            sendEvent(withName: "onError", body: ["status": "WEB_SOCKET_ERROR", "message": "Failed to create OTA-ABORT command"])
            return
        }
        
        sendMessage(jsonString)
    }
    
    private func initiateOTAUpdate(_ fileName: String) {
        guard let filePath = Bundle.main.path(forResource: fileName, ofType: nil),
              let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            sendEvent(withName: "onError", body:["status": "WEB_SOCKET_ERROR", "message": "Failed to read file: \(fileName)"])
            return
        }
        
        let pageSize: Int = 256
        let totalPages = (fileData.count + pageSize - 1) / pageSize
        

        let command: [String: Any] = [
            "CMD": "OTA-START",
            "START-PAGE": 1,
            "TOTAL-PAGES": totalPages
        ]

        // Following the drawio diagram
        // let command: [String: Any] = [
        //     "CMD": "OTA-TOTAL-PAGES",
        //     "LEN": totalPages
        // ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: command, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            sendEvent(withName: "onError", body:["status": "WEB_SOCKET_ERROR", "message": "Failed to create OTA-START command"])
            return
        }
        
        sendMessage(jsonString)
        
        // Send OTA pages here
        sendOTAPages(fileData, pageSize: pageSize, totalPages: totalPages)
    }
    
    private func sendOTAPages(_ fileData: Data, pageSize: Int, totalPages: Int) {
        var offset = 0
        
        for pageIndex in 1...totalPages {
            let pageData = fileData.subdata(in: offset..<offset + pageSize)
            let command: [String: Any] = [
                "CMD": "OTA-WRITE-PAGE",
                "PAGE-ID": pageIndex,
                "PAGE-DATA": pageData.base64EncodedString()
            ]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: command, options: []),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                sendEvent(withName: "onError", body: ["status": "WEB_SOCKET_ERROR", "message": "Failed to create OTA-WRITE-PAGE command"])
                return
            }
            
            sendMessage(jsonString)
            offset += pageSize
        }
        
        sendOTADone()
        sendDevReset()
    }
    
    private func sendOTADone() {
        let command = ["CMD": "OTA-DONE"]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: command, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            sendEvent(withName: "onError", body:["status": "WEB_SOCKET_ERROR", "message": "Failed to create OTA-DONE command"])
            return
        }
        
        sendMessage(jsonString)
    }
    
    private func sendDevReset() {
        let command = ["CMD": "DEV-RESET"]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: command, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            sendEvent(withName: "onError", body:["status": "WEB_SOCKET_ERROR", "message": "Failed to create OTA-DONE command"])
            return
        }
        
        sendMessage(jsonString)
    }
    


    private func handleOTAWritePage(_ message: String) {
        // Handle OTA-WRITE-PAGE response
    }
    
    private func handleonOTAStatus(_ message: String) {
        // Handle OTA status response
    }
    
    private func handleFirmwareVersion(_ message: String) {
        // Handle firmware version response
    }
    
    // MARK: - Helper Methods
    
    override func sendEvent(withName name: String, body: Any?) {
        DispatchQueue.main.async {
            super.sendEvent(withName: name, body: body)
        }
    }
}
