//
//  BaseJsonUtil.m
//  CGYJSBridgeDemo
//
//  Created by gaochongyang on 2018/4/26.
//  Copyright © 2018年 gaochongyang. All rights reserved.
//

#import "BaseJsonUtil.h"

@implementation BaseJsonUtil

+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
    if (jsonString == nil) {
        return nil;
    }
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&error];
    if (error) {
        NSLog(@"json解析失败： %@", error);
    }
    return dic;
}

+ (NSString *)dictionaryToJson:(NSDictionary *)dictionary {
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingPrettyPrinted error:&error];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

@end
