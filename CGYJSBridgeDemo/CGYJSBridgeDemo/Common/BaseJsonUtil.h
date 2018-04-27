//
//  BaseJsonUtil.h
//  CGYJSBridgeDemo
//
//  Created by gaochongyang on 2018/4/26.
//  Copyright © 2018年 gaochongyang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BaseJsonUtil : NSObject

/**
 *  json转dictionary
 *
 *  @param jsonString json字符串
 *
 *  @return dictionary，转换后的字典
 */
+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString;

/**
 *  dictionary转json
 *
 *  @param dictionary 数据字典
 *
 *  @return jsonString，转换后的json字符串
 */
+ (NSString *)dictionaryToJson:(NSDictionary *)dictionary;

@end
