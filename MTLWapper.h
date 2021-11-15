#ifndef LIBS_H
#define LIBS_H

#import <UIKit/UIKit.h>

@interface MetalViewController:UIViewController @end
@implementation MetalViewController
-(BOOL)prefersStatusBarHidden { return YES; }
@end

@interface MetalView:UIView @end
@implementation MetalView
    +(Class)layerClass { return [CAMetalLayer class]; }
@end

@interface MTLWapper:NSObject
-(MetalView *) view:(int)w :(int)h;
@end

#endif
