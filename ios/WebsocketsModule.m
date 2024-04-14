//
//  Websockets.m
//  mtls
//
//  Created by Goutham Gandhi Nadendla on 02/04/24.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(MTLSWebSocketModule, RCTEventEmitter)
    RCT_EXTERN_METHOD(connect:(NSString *)url)
@end