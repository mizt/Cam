#import "MTLWapper.h"

#import <Metal/Metal.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
void addMethod(Class cls,NSString *method,id block,const char *type,bool isClassMethod=false) {
        
    SEL sel = NSSelectorFromString(method);
    int ret = ([cls respondsToSelector:sel])?1:(([[cls new] respondsToSelector:sel])?2:0);
    if(ret) {
        class_addMethod(cls,(NSSelectorFromString([NSString stringWithFormat:@"_%@",(method)])),method_getImplementation(class_getInstanceMethod(cls,sel)),type);
        class_replaceMethod((ret==1)?object_getClass((id)cls):cls,sel,imp_implementationWithBlock(block),type);
    }
    else {
        class_addMethod((isClassMethod)?object_getClass((id)cls):cls,sel,imp_implementationWithBlock(block),type);
    }
}


#import "FileManager.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
namespace stb_image {
    #import "stb_image.h"
}

#import "Plane.h"
#import "MetalLayer.h"

class Vdig {
    
    private:
        
        const int WIDTH  = 1080;
        const int HEIGHT = 1920;
    
        unsigned int *buffer;
    
        id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate;
        
        AVCaptureDevice *device;
        NSDictionary *settings;
        AVCaptureDeviceInput *deviceInput;
        AVCaptureVideoDataOutput *dataOutput;
        AVCaptureConnection *videoConnection;
        AVCaptureSession *session;
    
#if TARGET_OS_SIMULATOR

        dispatch_source_t _timer;

#endif
        
    public:
        
        unsigned int *bytes() {
            return this->buffer;
        }
        
        Vdig(void (^onUpdate)(unsigned int *)) {

#if TARGET_OS_IOS && !TARGET_OS_SIMULATOR
            
            this->buffer = new unsigned int[WIDTH*HEIGHT];
            for(int k=0; k<WIDTH*HEIGHT; k++) this->buffer[k] = 0;

            if(objc_getClass("Delegate")==nil) { objc_registerClassPair(objc_allocateClassPair(objc_getClass("NSObject"),"Delegate",0)); }
            Class Delegate = objc_getClass("Delegate");
            addMethod(Delegate,@"captureOutput:didOutputSampleBuffer:fromConnection:",^(id me,AVCaptureOutput *output,CMSampleBufferRef sampleBuffer,AVCaptureConnection *connection) {
                
                CVImageBufferRef buf = CMSampleBufferGetImageBuffer(sampleBuffer);
                CVPixelBufferLockBaseAddress(buf,0);
                                
                int width = (int)CVPixelBufferGetWidth(buf);
                int height = (int)CVPixelBufferGetHeight(buf);
                
                if(width==WIDTH&&height==HEIGHT) {
                    
                    int row = ((int)CVPixelBufferGetBytesPerRow(buf))>>2;
                    unsigned int *base = (unsigned int *)CVPixelBufferGetBaseAddress(buf);
                                        
                    for(int i=0; i<HEIGHT; i++) {
                        for(int j=0; j<WIDTH; j++) {
                            unsigned int pixel = base[i*row+j];
                            buffer[i*WIDTH+j] = (pixel&0xFF00FF00)|((pixel>>16)&0xFF)|((pixel&0xFF)<<16);
                        }
                    }
                    
                    onUpdate(this->buffer);
                }
                else {
                    for(int k=0; k<WIDTH*HEIGHT; k++) this->buffer[k] = 0xFF000000;
                }
                
                CVPixelBufferUnlockBaseAddress(buf,0);
                
            },"v@:@@");
            this->delegate = [Delegate new];
            
            this->device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            this->deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:this->device error:NULL];
            
            this->settings = @{(id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
            this->dataOutput = [[AVCaptureVideoDataOutput alloc] init];
            this->dataOutput.videoSettings = this->settings;
            [this->dataOutput setSampleBufferDelegate:this->delegate queue:dispatch_get_main_queue()];
            
            this->session = [[AVCaptureSession alloc] init];
            [this->session addInput:this->deviceInput];
            [this->session addOutput:this->dataOutput];
            this->session.sessionPreset = AVCaptureSessionPreset1920x1080;
            
            [this->session beginConfiguration];
            
            for(AVCaptureConnection *connection in [this->dataOutput connections] ) {
                for(AVCaptureInputPort *port in [connection inputPorts] ) {
                    if([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                        this->videoConnection = connection;
                    }
                }
            }
            if([this->videoConnection isVideoOrientationSupported]) {
                [this->videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            }
           
            [this->session commitConfiguration];
            [this->session startRunning];

#else
            
            int w;
            int h;
            int bpp;
                
            this->buffer = (unsigned int *)stb_image::stbi_load([FileManager::path(@"test.png") UTF8String],&w,&h,&bpp,4);
            
            this->_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_queue_create("ENTER_FRAME",0));
            dispatch_source_set_timer(this->_timer,dispatch_time(0,0),(1.0/30.0)*1000000000,0);
            dispatch_source_set_event_handler(this->_timer,^{
                onUpdate(this->buffer);
            });
            if(this->_timer) dispatch_resume(this->_timer);
#endif

        }
        
        ~Vdig() {
            delete[] this->buffer;
 
#if TARGET_OS_SIMULATOR
            
            if(this->_timer) {
                dispatch_source_cancel(this->_timer);
                this->_timer = nullptr;
            }
#endif
            
        }
};

@implementation MTLWapper {
    MetalView *_view;
    Vdig *_vdig;
    MetalLayer<Plane> *_layer;
}

-(MetalView *) view:(int)w :(int)h {
    if(self->_view==nil) {
        
        CGRect rect = CGRectMake(0,0,w,h);

        self->_view = [[MetalView alloc] initWithFrame:CGRectMake(0,0,rect.size.width,rect.size.height)];
        self->_view.backgroundColor = [UIColor blueColor];
        
        self->_layer = new MetalLayer<Plane>((CAMetalLayer *)self->_view.layer);
        
        if(self->_layer&&self->_layer->init(rect.size.width,rect.size.height,@"default.metallib")) {

            if(self->_vdig==nil) {
                self->_vdig = new Vdig(^(unsigned int *bytes) {

                    [self->_layer->texture() replaceRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0 withBytes:bytes bytesPerRow:w<<2];
                    
                    self->_layer->update(^(id<MTLCommandBuffer> commandBuffer) {
                        self->_layer->cleanup();
                        
                        static dispatch_once_t oncePredicate;
                        dispatch_once(&oncePredicate,^{
                            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"Appear" object:nil]];
                        });
                    });
                });
            }
        }
    }
    return _view;
}
@end
