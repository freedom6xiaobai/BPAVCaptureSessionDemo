//
//  ViewController.m
//  demo
//
//  Created by baipeng on 2018/11/19.
//  Copyright © 2018年 Apple Inc. All rights reserved.
//

#import "ViewController.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
/**
 *  常量类
 */
#define IS_IOS_7 ([[[UIDevice currentDevice] systemVersion] floatValue] >=7.0 ? YES : NO)
#define IS_IOS_8 ([[[UIDevice currentDevice] systemVersion] floatValue] >=8.0 ? YES : NO)
#define IS_IPHONE5 (([[UIScreen mainScreen] bounds].size.height-568)?NO:YES)
#define WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define HEIGHT ([[UIScreen mainScreen] bounds].size.height)
#define START_POSITION ([[[UIDevice currentDevice] systemVersion] floatValue] >=7.0 ? 20 : 0)


@interface ViewController ()<
AVCaptureVideoDataOutputSampleBufferDelegate,
AVCaptureFileOutputRecordingDelegate>

@end

@implementation ViewController{
    AVCaptureSession *_captureSession;
    UIImageView *_outputImageView;
    AVCaptureVideoPreviewLayer *_captureLayer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:&error];
    if(!error){
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if(error) NSLog(@"Error while activating AudioSession : %@", error);
    }else{
        NSLog(@"Error while setting category of AudioSession : %@", error);
    }

    //MASK: - 输入
    //设置视频输入配置
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
    //设置音频输入配置
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    //MASK: - 输出
    //设置输出配置 data 每一帧展示
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc]init];
    videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)};
    [videoOutput setSampleBufferDelegate:self queue: dispatch_queue_create("cameraQueue", nil)];
    videoOutput.alwaysDiscardsLateVideoFrames = YES;


    //设置输出配置 file 文件
    //    AVCaptureMovieFileOutput *fileOutput = [[AVCaptureMovieFileOutput alloc]init];
    //    fileOutput.movieFragmentInterval = kCMTimeInvalid;
    //    AVCaptureConnection *connection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    //    // 前置摄像头翻转
    //    AVCaptureDevicePosition currentPosition = videoDevice.position;
    //    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront) {
    //        connection.videoMirrored = YES;
    //    } else {
    //        connection.videoMirrored = NO;
    //    }
    //    if (connection.isVideoStabilizationSupported) {
    //        [connection setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeAuto];
    //    }
    //沙盒路径
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject];
    //    if (connection.active) {
    //        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",path,@"movie.mov"]];
    //        [fileOutput startRecordingToOutputFileURL:url recordingDelegate:self];
    //    }

    //设置输出audio配置
    NSDictionary *audioSettings = @{AVFormatIDKey:@(kAudioFormatLinearPCM), // 格式
                                    AVSampleRateKey: @44100, // 采样率
                                    AVNumberOfChannelsKey: @1, // 声道数
                                    AVLinearPCMBitDepthKey: @16}; // 位深度
    [[[AVAudioRecorder alloc]initWithURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",path,@"audio.pcm"]] settings:audioSettings error:nil] record];

    //配置捕获会话
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    [_captureSession beginConfiguration];
    if ([_captureSession canAddInput:videoInput]) {//添加视频输入配置
        [_captureSession addInput:videoInput];
    }else{
        NSLog(@"error videoInput");
    }
    if ([_captureSession canAddInput:audioInput]) {//添加音频输入配置
        [_captureSession addInput:audioInput];
    }else{
        NSLog(@"error audioInput");
    }
    if ([_captureSession canAddOutput:videoOutput]) {//添加data视频输出配置
        [_captureSession addOutput:videoOutput];
    }else{
        NSLog(@"error videoOutput");
    }
    //    if ([_captureSession canAddOutput:fileOutput]) {//添加file视频输出配置
    //        [_captureSession addOutput:fileOutput];
    //    }else{
    //        NSLog(@"error fileOutput");
    //    }
    [_captureSession commitConfiguration];

    [_captureSession startRunning];


    //实时显示摄像头内容
    _captureLayer = [AVCaptureVideoPreviewLayer layerWithSession: _captureSession];
    _captureLayer.frame = CGRectMake(10,20, (WIDTH-20)/3, HEIGHT/3);
    _captureLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer: _captureLayer];


    //显示输出图片
    _outputImageView = [[UIImageView alloc]initWithFrame:CGRectMake(CGRectGetMaxX(_captureLayer.frame)+10, 20, CGRectGetWidth(_captureLayer.frame), CGRectGetHeight(_captureLayer.frame))];
    _outputImageView.contentMode = UIViewContentModeScaleAspectFit;
    _outputImageView.clipsToBounds = YES;
    [self.view addSubview:_outputImageView];


    UIButton *stopButton = [[UIButton alloc]initWithFrame:CGRectMake(10, CGRectGetMaxY(_captureLayer.frame)+30, CGRectGetWidth(_outputImageView.frame), 50)];
    stopButton.backgroundColor = [UIColor blackColor];
    [stopButton setTitle:@"stop" forState:UIControlStateNormal];
    [stopButton setTitle:@"stop" forState:UIControlStateHighlighted];
    [stopButton addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stopButton];

    UIButton *startButton = [[UIButton alloc]initWithFrame:CGRectMake(CGRectGetMaxX(stopButton.frame)+10, CGRectGetMaxY(_outputImageView.frame)+30, CGRectGetWidth(_outputImageView.frame), 50)];
    startButton.backgroundColor = [UIColor blackColor];
    [startButton setTitle:@"start" forState:UIControlStateNormal];
    [startButton setTitle:@"start" forState:UIControlStateHighlighted];
    [startButton addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startButton];

}

#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress,width, height, 8, bytesPerRow, colorSpace,kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);

    UIImage *image= [UIImage imageWithCGImage:newImage scale:1 orientation:UIImageOrientationLeft];
    CGImageRelease(newImage);
    if (_captureLayer.connection.videoOrientation == AVCaptureVideoOrientationLandscapeRight) {
        image = [image rotate:UIImageOrientationDownMirrored];
        image = [image subImageWithRect:CGRectMake(image.size.width/2, 0, image.size.width/2, image.size.height)];
    }else if (_captureLayer.connection.videoOrientation == AVCaptureVideoOrientationLandscapeLeft){
        image = [image rotate:UIImageOrientationUpMirrored];
        image = [image subImageWithRect:CGRectMake(0, 0, image.size.width/2, image.size.height)];
    }else if (_captureLayer.connection.videoOrientation == AVCaptureVideoOrientationPortrait){
        image = [image rotate:UIImageOrientationRightMirrored];
    }else{
        image = [image rotate:UIImageOrientationLeftMirrored];
    }
    [_outputImageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);

    [self changePreviewOrientation:UIApplication.sharedApplication.statusBarOrientation];

}
- (void)changePreviewOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (!_captureLayer) {
        return;
    }
    [CATransaction begin];
    if (interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        _captureLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;

    }else if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft){
        _captureLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;

    }else if (interfaceOrientation == UIDeviceOrientationPortrait){
        _captureLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;

    }else if (interfaceOrientation == UIDeviceOrientationPortraitUpsideDown){
        _captureLayer.connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
    }
    [CATransaction commit];
}


#pragma mark - AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections{
    NSLog(@"%@",fileURL);


}
- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(nullable NSError *)error{
    BOOL recordedSuccessfully = YES;
    if ([error code] != noErr){
        id value = [[error userInfo] objectForKey:AVErrorRecordingSuccessfullyFinishedKey];
        if (value)
            recordedSuccessfully = [value boolValue];
        NSLog(@"A problem occurred while recording: %@", error);
    }
    if (recordedSuccessfully) {
        NSLog(@"recordedSuccessfully");
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL
                                    completionBlock:^(NSURL *assetURL, NSError *error)
         {
             UIAlertView *alert;
             if (!error)
             {
                 alert = [[UIAlertView alloc] initWithTitle:@"Video Saved"
                                                    message:@"The movie was successfully saved to you photos library"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil, nil];
             }
             else
             {
                 alert = [[UIAlertView alloc] initWithTitle:@"Error Saving Video"
                                                    message:@"The movie was not saved to you photos library"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"

                                          otherButtonTitles:nil, nil];
             }

             [alert show];
         }
         ];
    }
}

-(void)stop{
    [_captureSession stopRunning];
}
-(void)start{
    [_captureSession startRunning];
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
    [self changePreviewOrientation:(UIInterfaceOrientation)toInterfaceOrientation];

}



@end








//由角度转换弧度
#define kDegreesToRadian(x)      (M_PI * (x) / 180.0)
//由弧度转换角度
#define kRadianToDegrees(radian) (radian * 180.0) / (M_PI)

@implementation UIImage (Rotate)

/** 纠正图片的方向 */
- (UIImage *)fixOrientation
{
    if (self.imageOrientation == UIImageOrientationUp) return self;

    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;

    switch (self.imageOrientation)
    {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, self.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;

        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;

        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, self.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }

    switch (self.imageOrientation)
    {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;

        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, self.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }

    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, self.size.width, self.size.height,
                                             CGImageGetBitsPerComponent(self.CGImage), 0,
                                             CGImageGetColorSpace(self.CGImage),
                                             CGImageGetBitmapInfo(self.CGImage));
    CGContextConcatCTM(ctx, transform);

    switch (self.imageOrientation)
    {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            CGContextDrawImage(ctx, CGRectMake(0,0,self.size.height,self.size.width), self.CGImage);
            break;

        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,self.size.width,self.size.height), self.CGImage);
            break;
    }

    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);

    return img;
}

/** 按给定的方向旋转图片 */
- (UIImage*)rotate:(UIImageOrientation)orient
{
    CGRect bnds = CGRectZero;
    UIImage* copy = nil;
    CGContextRef ctxt = nil;
    CGImageRef imag = self.CGImage;
    CGRect rect = CGRectZero;
    CGAffineTransform tran = CGAffineTransformIdentity;

    rect.size.width = CGImageGetWidth(imag);
    rect.size.height = CGImageGetHeight(imag);

    bnds = rect;

    switch (orient)
    {
        case UIImageOrientationUp:
            return self;

        case UIImageOrientationUpMirrored:
            tran = CGAffineTransformMakeTranslation(rect.size.width, 0.0);
            tran = CGAffineTransformScale(tran, -1.0, 1.0);
            break;

        case UIImageOrientationDown:
            tran = CGAffineTransformMakeTranslation(rect.size.width,
                                                    rect.size.height);
            tran = CGAffineTransformRotate(tran, M_PI);
            break;

        case UIImageOrientationDownMirrored:
            tran = CGAffineTransformMakeTranslation(0.0, rect.size.height);
            tran = CGAffineTransformScale(tran, 1.0, -1.0);
            break;

        case UIImageOrientationLeft:
            bnds = swapWidthAndHeight(bnds);
            tran = CGAffineTransformMakeTranslation(0.0, rect.size.width);
            tran = CGAffineTransformRotate(tran, 3.0 * M_PI / 2.0);
            break;

        case UIImageOrientationLeftMirrored:
            bnds = swapWidthAndHeight(bnds);
            tran = CGAffineTransformMakeTranslation(rect.size.height,
                                                    rect.size.width);
            tran = CGAffineTransformScale(tran, -1.0, 1.0);
            tran = CGAffineTransformRotate(tran, 3.0 * M_PI / 2.0);
            break;

        case UIImageOrientationRight:
            bnds = swapWidthAndHeight(bnds);
            tran = CGAffineTransformMakeTranslation(rect.size.height, 0.0);
            tran = CGAffineTransformRotate(tran, M_PI / 2.0);
            break;

        case UIImageOrientationRightMirrored:
            bnds = swapWidthAndHeight(bnds);
            tran = CGAffineTransformMakeScale(-1.0, 1.0);
            tran = CGAffineTransformRotate(tran, M_PI / 2.0);
            break;

        default:
            return self;
    }

    UIGraphicsBeginImageContext(bnds.size);
    ctxt = UIGraphicsGetCurrentContext();

    switch (orient)
    {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            CGContextScaleCTM(ctxt, -1.0, 1.0);
            CGContextTranslateCTM(ctxt, -rect.size.height, 0.0);
            break;

        default:
            CGContextScaleCTM(ctxt, 1.0, -1.0);
            CGContextTranslateCTM(ctxt, 0.0, -rect.size.height);
            break;
    }

    CGContextConcatCTM(ctxt, tran);
    CGContextDrawImage(UIGraphicsGetCurrentContext(), rect, imag);

    copy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return copy;
}

/** 垂直翻转 */
- (UIImage *)flipVertical
{
    return [self rotate:UIImageOrientationDownMirrored];
}

/** 水平翻转 */
- (UIImage *)flipHorizontal
{
    return [self rotate:UIImageOrientationUpMirrored];
}

/** 将图片旋转弧度radians */
- (UIImage *)imageRotatedByRadians:(CGFloat)radians
{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.size.width, self.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(radians);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;

    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();

    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);

    //   // Rotate the image context
    CGContextRotateCTM(bitmap, radians);

    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), [self CGImage]);

    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return newImage;
}

/** 将图片旋转角度degrees */
- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees
{
    return [self imageRotatedByRadians:kDegreesToRadian(degrees)];
}

/** 交换宽和高 */
static CGRect swapWidthAndHeight(CGRect rect)
{
    CGFloat swap = rect.size.width;

    rect.size.width = rect.size.height;
    rect.size.height = swap;

    return rect;
}

@end





@implementation UIImage (SubImage)

#pragma mark - 截取当前image对象rect区域内的图像
- (UIImage *)subImageWithRect:(CGRect)rect
{
    CGImageRef newImageRef = CGImageCreateWithImageInRect(self.CGImage, rect);

    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];

    CGImageRelease(newImageRef);

    return newImage;
}

#pragma mark - 压缩图片至指定尺寸
- (UIImage *)rescaleImageToSize:(CGSize)size
{
    CGRect rect = (CGRect){CGPointZero, size};

    UIGraphicsBeginImageContext(rect.size);

    [self drawInRect:rect];

    UIImage *resImage = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return resImage;
}

#pragma mark - 压缩图片至指定像素
- (UIImage *)rescaleImageToPX:(CGFloat )toPX
{
    CGSize size = self.size;

    if(size.width <= toPX && size.height <= toPX)
    {
        return self;
    }

    CGFloat scale = size.width / size.height;

    if(size.width > size.height)
    {
        size.width = toPX;
        size.height = size.width / scale;
    }
    else
    {
        size.height = toPX;
        size.width = size.height * scale;
    }

    return [self rescaleImageToSize:size];
}

#pragma mark - 指定大小生成一个平铺的图片
- (UIImage *)getTiledImageWithSize:(CGSize)size
{
    UIView *tempView = [[UIView alloc] init];
    tempView.bounds = (CGRect){CGPointZero, size};
    tempView.backgroundColor = [UIColor colorWithPatternImage:self];

    UIGraphicsBeginImageContext(size);
    [tempView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *bgImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return bgImage;
}

#pragma mark - UIView转化为UIImage
+ (UIImage *)imageFromView:(UIView *)view
{
    CGFloat scale = [UIScreen mainScreen].scale;
    UIGraphicsBeginImageContextWithOptions(view.frame.size, NO, scale);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

#pragma mark - 将两个图片生成一张图片
+ (UIImage*)mergeImage:(UIImage*)firstImage withImage:(UIImage*)secondImage
{
    CGImageRef firstImageRef = firstImage.CGImage;
    CGFloat firstWidth = CGImageGetWidth(firstImageRef);
    CGFloat firstHeight = CGImageGetHeight(firstImageRef);
    CGImageRef secondImageRef = secondImage.CGImage;
    CGFloat secondWidth = CGImageGetWidth(secondImageRef);
    CGFloat secondHeight = CGImageGetHeight(secondImageRef);
    CGSize mergedSize = CGSizeMake(MAX(firstWidth, secondWidth), MAX(firstHeight, secondHeight));
    UIGraphicsBeginImageContext(mergedSize);
    [firstImage drawInRect:CGRectMake(0, 0, firstWidth, firstHeight)];
    [secondImage drawInRect:CGRectMake(0, 0, secondWidth, secondHeight)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
