//
//  MqttClientEx.m
//  Trader
//
//  Created by xuwq on 15/7/7.
//
//

#import "MqttClientEx.h"

@implementation MqttClientEx

- (MqttClientEx*) initWithClientId: (NSString*) clientId
{
    self=[super initWithClientId:clientId];
    if (self) {
        mqttQueuePriority = DISPATCH_QUEUE_PRIORITY_BACKGROUND;
        mqttQueue = dispatch_queue_create("cn.qhjyz.mqttclient",DISPATCH_QUEUE_SERIAL);
        
        __weak MqttClientEx* weakSelf=self;
        self.messageHandlerDict=[NSMutableDictionary dictionary];
        self.messageHandler=^(MQTTMessage* message)
        {
            dispatch_sync(mqttQueue, ^{
                if (weakSelf.messageHandlerDict.count>0) {
                    NSMutableDictionary* keyHandlers=[weakSelf.messageHandlerDict objectForKey:message.topic];
                    if (keyHandlers) {
                        NSArray* keys = keyHandlers.allKeys;
                        for (NSString* key in keys) {
                            MQTTMessageHandler d=[keyHandlers objectForKey:key];
                            if (d) {
                                d(message);
                            }
                        }
                    }
                }
            });
        };
    }
    return self;
}
- (void)subscribe:(NSString *)topic wittMessageHandler:(MQTTMessageHandler)messageHandler withCompletionHandler:(MQTTSubscriptionCompletionHandler)completionHandler
{
    [self subscribe:topic withTag:@"default" wittMessageHandler:messageHandler withCompletionHandler:completionHandler];
    
}

- (void)unsubscribe:(NSString *)topic withCompletionHandler:(void (^)(void))completionHandler
{
    [self unsubscribe:topic withTag:@"default" withCompletionHandler:completionHandler];
}

- (void)subscribe:(NSString *)topic withTag:(NSString*)tag wittMessageHandler:(MQTTMessageHandler)messageHandler withCompletionHandler:(MQTTSubscriptionCompletionHandler)completionHandler
{
	if( topic == nil || tag == nil || messageHandler == nil ){
		return ;
	}
    dispatch_async(mqttQueue, ^{
        NSMutableDictionary* keyHandlers=[self.messageHandlerDict objectForKey:topic];
        if (keyHandlers==nil) {
            keyHandlers=[NSMutableDictionary dictionary];
        }
        if (keyHandlers.count==0) {
            [super subscribe:topic withCompletionHandler:completionHandler];
            //subscribe once
        }
        [keyHandlers setObject:[messageHandler copy] forKey:tag];
        [self.messageHandlerDict setObject:keyHandlers forKey:topic];
    });
}

- (void)unsubscribe:(NSString *)topic withTag:(NSString*)tag withCompletionHandler:(void (^)(void))completionHandler
{
	if( topic == nil || tag == nil  ){
		return;
	}
	
    dispatch_async(mqttQueue, ^{
        NSMutableDictionary* keyHandlers=[self.messageHandlerDict objectForKey:topic];
        if (keyHandlers) {
            [keyHandlers removeObjectForKey:tag];
            if (keyHandlers.count==0) {
                [super unsubscribe:topic withCompletionHandler:completionHandler];//unsubscribe only when empty
            }
            dispatch_barrier_async(mqttQueue, ^{
                [self.messageHandlerDict setObject:keyHandlers forKey:topic];
            });
        }
    });
}

-(void) unsubscribeAll
{
    NSMutableArray* topics=[NSMutableArray array];
    for (NSString* topic in self.messageHandlerDict) {
        [topics addObject:topic];
    }
    for (NSString* topic in topics) {
        [self unsubscribe:topic withCompletionHandler:nil];
    }
}

-(void) reSubscribeAll{
    for (NSString* topic in self.messageHandlerDict) {
        [super subscribe:topic withCompletionHandler:nil];
    }
}


@end
