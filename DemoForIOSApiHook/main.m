//
//  main.m
//  DemoForIOSApiHook
//
//  Created by DarkLinden on A/21/2013.
//  Copyright (c) 2013 darklinden. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#import <dlfcn.h>

#import <objc/objc.h>
#import <objc/runtime.h>
#import "fishhook.h"

static int (*orig_close)(int);
static int (*orig_open)(const char *, int, ...);

void save_original_symbols() {
    orig_close = dlsym(RTLD_DEFAULT, "close");
    orig_open = dlsym(RTLD_DEFAULT, "open");
}

int my_close(int fd) {
    printf("Calling real close(%d)\n", fd);
    return orig_close(fd);
}

int my_open(const char *path, int oflag, ...) {
    va_list ap = {0};
    mode_t mode = 0;
    
    if ((oflag & O_CREAT) != 0) {
        // mode only applies to O_CREAT
        va_start(ap, oflag);
        mode = va_arg(ap, int);
        va_end(ap);
        printf("Calling real open('%s', %d, %d)\n", path, oflag, mode);
        return orig_open(path, oflag, mode);
    } else {
        printf("Calling real open('%s', %d)\n", path, oflag);
        return orig_open(path, oflag, mode);
    }
}

static void apiHookClass(Class selectClass,
                         Class hookClass,
                         SEL localSelector,
                         SEL privateSelector,
                         SEL originalSelector)
{
    //local get method
    Method local = class_getInstanceMethod(selectClass, localSelector);
    
    //private create method
    Method private = class_getInstanceMethod(hookClass, privateSelector);
    
    // bind original method
    IMP localImp = method_getImplementation(local);
    class_addMethod(selectClass,
                    originalSelector,
                    localImp,
                    method_getTypeEncoding(local));
    
    // replace local method
    IMP privateImp = method_getImplementation(private);
    class_replaceMethod(selectClass,
                        localSelector,
                        privateImp,
                        method_getTypeEncoding(local));
}

@interface O_hooker : NSObject

@end

@implementation O_hooker

- (NSString *)privateAbsoluteString
{
    NSLog(@"hook function %@", self);
    return [self originalAbsoluteString];
}

@end

@interface O_test : NSObject
@property (nonatomic, strong) NSString *string_test;
@end

@implementation O_test

- (id)init
{
    self = [super init];
    if (self) {
        [self addObserverForAllProperties:self
                                  options:NSKeyValueObservingOptionPrior
                                  context:nil];
    }
    return self;
}

- (void)addObserverForAllProperties:(NSObject *)observer
                            options:(NSKeyValueObservingOptions)options
                            context:(void *)context {
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    for (size_t i = 0; i < count; ++i) {
        NSString *key = [NSString stringWithCString:property_getName(properties[i])
                                           encoding:NSUTF8StringEncoding];
        [self addObserver:observer
               forKeyPath:key
                  options:options
                  context:context];
    }
    free(properties);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    NSLog(@"%@ %@ %@", keyPath, object, change);
}

@end

int main(int argc, char * argv[])
{
    @autoreleasepool {
        
#if 0
        //hook 1
        save_original_symbols();
        rebind_symbols((struct rebinding[2]){{"close", my_close}, {"open", my_open}}, 2);
        // Open our own binary and print out first 4 bytes (which is the same
        // for all Mach-O binaries on a given architecture)
        int fd = open(argv[0], O_RDONLY);
        uint32_t magic_number = 0;
        read(fd, &magic_number, 4);
        printf("Mach-O Magic Number: %x \n", magic_number);
        close(fd);
#endif
        
#if 1
        //hook 2
        O_hooker *hooker = [[O_hooker alloc] init];
        [hooker release];
        
        NSURL *url = [NSURL URLWithString:@"http://www.baidu.com"];
        apiHookClass([NSURL class],
                     [O_hooker class],
                     @selector(absoluteString),
                     @selector(privateAbsoluteString),
                     @selector(originalAbsoluteString));
        
        NSString *str = [url absoluteString];
        NSLog(@"%@", str);
#endif
      
#if 0
//        // property
//        id LenderClass = objc_getClass("O_test");
//        unsigned int outCount, i;
//        objc_property_t *properties = class_copyPropertyList(LenderClass, &outCount);
//        for (i = 0; i < outCount; i++) {
//            objc_property_t property = properties[i];
//            NSLog(@"%s %s\n", property_getName(property), property_getAttributes(property));
//        }
        O_test *test = [[O_test alloc] init];
        test.string_test = @"1";
        test.string_test = nil;
        test.string_test = @"";
        
#endif
        
        exit(0);
    }
}


