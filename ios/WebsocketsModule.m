//
//  Websocket.m
//  klynkApp
//
//  Created by Goutham Gandhi Nadendla on 17/04/24.
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(MTLSWebSocket, RCTEventEmitter)
    RCT_EXTERN_METHOD(connect:(NSString *)url)
    RCT_EXTERN_METHOD(disconnect)
    RCT_EXTERN_METHOD(sendMessage:(NSString *)message)
    RCT_EXTERN_METHOD(startOTAUpdate:(NSString *)fileName)
    RCT_EXTERN_METHOD(isClientConnected:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
@end  
