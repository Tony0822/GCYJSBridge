//
//  JSBridge.m
//  CGYJSBridgeDemo
//
//  Created by gaochongyang on 2018/4/26.
//  Copyright © 2018年 gaochongyang. All rights reserved.
//

#import "JSBridge.h"
#import "BaseJsonUtil.h"

#define kCustomProtocolScheme @"gs-bridge"
#define kBridgeLoaded         @"__BRIDGE_LOADED__"
#define kQueueHasMessage      @"__GS_QUEUE_MESSAGE__"

@interface JSBridge ()<WKNavigationDelegate> {
    WKWebView *_webView;
    long _uniqueId;
    NSMutableDictionary *_responseCallbacks;
    NSMutableDictionary *_messageHandlers;
    __weak id<WKNavigationDelegate> _webViewDelegate;
}
@property (nonatomic, strong) NSMutableArray *startupMessageQueue;

@end


@implementation JSBridge

static bool logging = false;

+ (instancetype)bridgeForWebView:(WKWebView *)webView {
    JSBridge *bridge = [[JSBridge alloc] init];
    [bridge _platformSpecificSetup:webView webViewDelegate:nil];
    return bridge;
}

+ (instancetype)bridgeForWebView:(WKWebView *)webView webViewDelegate:(id<WKNavigationDelegate>)webViewDelegate {
    JSBridge *bridge = [[JSBridge alloc] init];
    [bridge _platformSpecificSetup:webView webViewDelegate:webViewDelegate];
    return bridge;
}

+ (void)enableLogging {
    logging = true;
}

#pragma mark - Public Methods
- (void)registerHandler:(NSString *)handlerName handler:(JSBridgeHandler)handler {
    _messageHandlers[handlerName] = [handler copy];
}

- (void)callHandler:(NSString *)handlerName {
    [self callHandler:handlerName data:nil];
}

- (void)callHandler:(NSString *)handlerName data:(id)data {
    [self callHandler:handlerName data:data handler:nil];
}

- (void)callHandler:(NSString *)handlerName data:(id)data handler:(JSBridgeResponseCallback)responseCallback {
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    if (responseCallback) {
        NSString *callbackId = [NSString stringWithFormat:@"objc_cb_%ld", ++_uniqueId];
        _responseCallbacks[callbackId] = [responseCallback copy];
        [dic setObject:callbackId forKey:@"callbackId"];
    }
    if (data) {
        [dic setObject:data forKey:@"data"];
    }
    [dic setObject:handlerName forKey:@"handlerName"];
    [self _queueMessage:dic];

}
#pragma mark - Private Methods
- (void)_platformSpecificSetup:(id)webView webViewDelegate:(id<WKNavigationDelegate>)webViewDelegate {
    _uniqueId = 0;
    _responseCallbacks = [NSMutableDictionary dictionary];
    _messageHandlers = [NSMutableDictionary dictionary];
    _startupMessageQueue = [NSMutableArray array];
    _webView = webView;
    _webView.navigationDelegate = self;
    _webViewDelegate = webViewDelegate;
}

- (void)_queueMessage:(NSDictionary *)message {
    if (_startupMessageQueue) {
        [_startupMessageQueue addObject:message];
    } else {
        [self _dispatchMessage:message];
    }
}

/**
 向H5传递数据信息
 
 @param message 数据
 */
- (void)_dispatchMessage:(NSDictionary *)message {
    NSString *messageJSON = [BaseJsonUtil dictionaryToJson:message];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
    [self _log:@"SEND" json:messageJSON];
    NSString *javascriptCommand = [NSString stringWithFormat:@"JSBridge._handleMessageFromApp('%@');", messageJSON];
    if ([[NSThread currentThread] isMainThread]) {
        [self _evaluateJavascript:javascriptCommand completionHandler:nil];
        
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self _evaluateJavascript:javascriptCommand completionHandler:nil];
        });
    }
}

- (void)_log:(NSString *)action json:(id)json {
    if (!logging) {
        return;
    }
    if (![json isKindOfClass:[NSString class]]) {
        json = [BaseJsonUtil dictionaryToJson:json];
    }
    if ([json length] > 500) {
        NSLog(@"JSBridge %@: %@ [...]", action, [json substringToIndex:500]);
    } else {
        NSLog(@"JSBridge %@: %@", action, json);
    }
}

- (NSString *)_evaluateJavascript:(NSString*)javascriptCommand completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler {
    [_webView evaluateJavaScript:javascriptCommand completionHandler:completionHandler];
    return NULL;
}

-(BOOL)_isCorrectProcotocolScheme:(NSURL *)url {
    if([[url scheme] isEqualToString:kCustomProtocolScheme]) {
        return YES;
    } else {
        return NO;
    }
}

-(BOOL)_isBridgeLoadedURL:(NSURL*)url {
    return ([[url scheme] isEqualToString:kCustomProtocolScheme] && [[url host] isEqualToString:kBridgeLoaded]);
}

-(BOOL)_isQueueMessageURL:(NSURL*)url {
    if([[url host] isEqualToString:kQueueHasMessage]){
        return YES;
    } else {
        return NO;
    }
}

- (void)_flushMessageQueue {
    __weak typeof(self) weakself = self;
    [_webView evaluateJavaScript:[self _fetchQueueString] completionHandler:^(NSString* result, NSError* error) {
        if (error != nil) {
            NSLog(@"JSBridge: WARNING: Error when trying to fetch data from WKWebView: %@", error);
        }
        [weakself _handleMessage:result];
    }];
}

- (NSString *)_fetchQueueString {
    return @"JSBridge._fetchQueue();";
}

-(void)_logUnkownMessage:(NSURL *)url {
    NSLog(@"JSBridge: WARNING: Received unknown JSBridge command %@://%@", kCustomProtocolScheme, [url path]);
}

- (NSArray *)_deserializeMessageJSON:(NSString *)messageJSON {
    return [NSJSONSerialization JSONObjectWithData:[messageJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

/**
 注入JSBridge
 */
- (void)_injectJavascriptFile {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"bridge.js" ofType:@"txt"];
    NSString *js = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    __weak typeof(self) weakself = self;
    [self _evaluateJavascript:js completionHandler:^(id obj, NSError * _Nullable error) {
        if (weakself.startupMessageQueue) {
            NSArray *queue = weakself.startupMessageQueue;
            weakself.startupMessageQueue = nil;
            for (id queuedMessage in queue) {
                [weakself _dispatchMessage:queuedMessage];
            }
        }
    }];
}

/**
 处理H5传递过来的数据
 
 @param messageQueueString 数据队列
 */
- (void)_handleMessage:(NSString *)messageQueueString{
    if (messageQueueString == nil || messageQueueString.length == 0) {
        NSLog(@"JSBridge: WARNING: MessageQueue is nil");
        return;
    }
    id messages = [self _deserializeMessageJSON:messageQueueString];
    for (NSDictionary *message in messages) {
        if (![message isKindOfClass:[NSDictionary class]]) {
            NSLog(@"JSBridge: WARNING: Invalid %@ received: %@", [message class], message);
            continue;
        }
        [self _log:@"Receive:" json:message];
        NSString *responseId = message[@"responseId"];
        if (responseId) {
            JSBridgeResponseCallback responseCallback = _responseCallbacks[responseId];
            responseCallback(message[@"responseData"]);
            [_responseCallbacks removeObjectForKey:responseId];
        } else {
            JSBridgeResponseCallback responseCallback = NULL;
            NSString *callbackId = message[@"callbackId"];
            if (callbackId) {
                responseCallback = ^(id responseData) {
                    if (responseData == nil) {
                        responseData = [NSNull null];
                    }
                    NSDictionary *msg = @{ @"responseId":callbackId, @"responseData":responseData };
                    [self _queueMessage:msg];
                };
            } else {
                responseCallback = ^(id ignoreResponseData) {
                };
            }
            JSBridgeHandler handler = _messageHandlers[message[@"handlerName"]];
            if (!handler) {
                NSLog(@"JSBridge:No handler for message from JS: %@", message);
                continue;
            }
            handler(message[@"data"], responseCallback);
        }
    }
}

#pragma mark - WKWebViewDelegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (webView != _webView) {
        return;
    }
    NSURL *url = navigationAction.request.URL;
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if ([self _isCorrectProcotocolScheme:url]) {
        if ([self _isBridgeLoadedURL:url]) {
            [self _injectJavascriptFile];
        }  else if ([self _isQueueMessageURL:url]) {
            [self _flushMessageQueue];
        }else {
            [self _logUnkownMessage:url];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    } else if ([[url scheme] isEqualToString:@"tel"]) {
        NSString *resourceSpecifier = [url resourceSpecifier];
        NSString *callPhone = [NSString stringWithFormat:@"telprompt://%@", resourceSpecifier];
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:callPhone]];
        });
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        [_webViewDelegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if (webView != _webView) {
        return;
    }
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        [strongDelegate webView:webView didStartProvisionalNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (webView != _webView) {
        return;
    }
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [strongDelegate webView:webView didFinishNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (webView != _webView) { return; }
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFailNavigation:withError:)]) {
        [strongDelegate webView:webView didFailNavigation:navigation withError:error];
    }
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (webView != _webView) { return; }
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)]) {
        [strongDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
    }
}
@end
