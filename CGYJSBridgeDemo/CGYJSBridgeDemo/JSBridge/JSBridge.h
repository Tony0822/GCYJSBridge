//
//  JSBridge.h
//  CGYJSBridgeDemo
//
//  Created by gaochongyang on 2018/4/26.
//  Copyright © 2018年 gaochongyang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

/**
 *  返回数据给h5回调方法
 *
 *  @param responseData 传递数据
 */
typedef void (^JSBridgeResponseCallback)(id responseData);
/**
 *  处理h5事件
 *
 *  @param data             h5传递的数据
 *  @param responseCallback 返回数据给h5回调
 */
typedef void (^JSBridgeHandler)(id data, JSBridgeResponseCallback responseCallback);

@interface JSBridge : NSObject

/**
 webView注册JSBridge

 @param webView webview
 @return JSBridge对象
 */
+ (instancetype)bridgeForWebView:(WKWebView *)webView;

/**
 webView注册JSBridge
 
 @param webView webView
 @param webViewDelegate WKNavigationDelegate代理
 @return JSBridge对象
 */
+ (instancetype)bridgeForWebView:(WKWebView *)webView webViewDelegate:(id<WKNavigationDelegate>)webViewDelegate;

/**
 *  开启调试日志
 */
+ (void)enableLogging;

/**
 *  webview注册一个方法回调
 *
 *  @param handlerName 方法名和webview保持一致
 *  @param handler     方法回调
 */
- (void)registerHandler:(NSString *)handlerName handler:(JSBridgeHandler)handler;

/**
 *  本地调h5方法
 *
 *  @param handlerName 方法名
 */
- (void)callHandler:(NSString *)handlerName;

/**
 *  本地调h5方法
 *
 *  @param handlerName 方法名
 *  @param data 传递数据
 */
- (void)callHandler:(NSString *)handlerName data:(id)data;

/**
 *  本地调h5方法
 *
 *  @param handlerName      方法名
 *  @param data             传递数据
 *  @param responseCallback h5处理成功后的回调
 */
- (void)callHandler:(NSString *)handlerName data:(id)data handler:(JSBridgeResponseCallback)responseCallback;

@end
