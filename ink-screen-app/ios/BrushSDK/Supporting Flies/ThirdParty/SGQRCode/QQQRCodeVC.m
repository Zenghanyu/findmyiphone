//
//  QQQRCodeVC.m
//  BrushSDK
//
//  Created by XTMacMini on 2025/2/18.
//



#import "QQQRCodeVC.h"
#import "SGQRCode.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <Vision/Vision.h>
#import "UtilsMacros.h"

@interface QQQRCodeVC ()<AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@property (nonatomic, strong) SGScanView *scanView;
@property (nonatomic, strong) UILabel *promptLabel;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) dispatch_queue_t metadataQueue;
@property (nonatomic, strong) dispatch_queue_t visionQueue;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCaptureDevice *captureDevice;
@property (nonatomic, assign) BOOL foundResult;
@property (nonatomic, assign) BOOL didRequestCameraSetup;
@property (nonatomic, assign) BOOL visionRequestInFlight;
@property (nonatomic, assign) CFTimeInterval lastVisionScanTime;
@property (nonatomic, assign) CGImagePropertyOrientation cachedVisionOrientation;
@property (nonatomic, assign) CGFloat initialZoomFactor;
@property (nonatomic, assign) NSTimeInterval visionScanInterval;

@end

@implementation QQQRCodeVC

- (void)dealloc {
    NSLog(@"QQQRCodeVC - dealloc");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stop];
    [self.metadataOutput setMetadataObjectsDelegate:nil queue:nil];
    [self.videoDataOutput setSampleBufferDelegate:nil queue:nil];
}

- (void)start {
    self.foundResult = NO;
    [self requestCameraAccessAndConfigureIfNeeded];
    [self startSession];
    [self.scanView startScanning];
}

- (void)stop {
    [self stopSession];
    [self.scanView stopScanning];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.backgroundColor = [UIColor blackColor];
    
    [self configureNav];
    
    [self configureUI];
    
    [self configureQRCode];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self start];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stop];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.scanView.frame = self.view.bounds;
    self.scanView.scanFrame = self.view.bounds;
    self.previewLayer.frame = self.view.bounds;
    CGFloat promptLabelY = 0.73 * self.view.frame.size.height;
    self.promptLabel.frame = CGRectMake(0, promptLabelY, self.view.frame.size.width, 25);
    [self updatePreviewOrientation];
}

- (void)configureUI {
    [self.view addSubview:self.scanView];
    [self.view addSubview:self.promptLabel];
}

- (void)configureQRCode {
    self.sessionQueue = dispatch_queue_create("com.qqqrcode.session", DISPATCH_QUEUE_SERIAL);
    self.metadataQueue = dispatch_queue_create("com.qqqrcode.metadata", DISPATCH_QUEUE_SERIAL);
    self.visionQueue = dispatch_queue_create("com.qqqrcode.vision", DISPATCH_QUEUE_SERIAL);
    self.cachedVisionOrientation = kCGImagePropertyOrientationRight;
    self.initialZoomFactor = 1.5;
    self.visionScanInterval = 0.18;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [self requestCameraAccessAndConfigureIfNeeded];
}

- (void)handleDetectedResult:(NSString *)result vibrate:(BOOL)vibrate {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleDetectedResult:result vibrate:vibrate];
        });
        return;
    }
    
    if (result.length == 0 || self.foundResult) {
        return;
    }
    
    self.foundResult = YES;
    [self stop];
    
    if (vibrate) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }

    //TDO
    if ([self.delegate respondsToSelector:@selector(scanCodeResultString:)]) {
        [self.delegate scanCodeResultString:result];
    }
    
    [self.navigationController popViewControllerAnimated:NO];
}

- (void)configureNav {
    self.navigationItem.title = XTLS(@"ScanQR");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:XTLS(@"PhotoAlbum") style:(UIBarButtonItemStyleDone) target:self action:@selector(rightBarButtonItenAction)];
}

- (void)rightBarButtonItenAction {
    [SGPermission permissionWithType:SGPermissionTypePhoto completion:^(SGPermission * _Nonnull permission, SGPermissionStatus status) {
        if (status == SGPermissionStatusNotDetermined) {
            [permission request:^(BOOL granted) {
                if (granted) {
                    NSLog(@"第一次授权成功");
                    [self _enterImagePickerController];
                } else {
                    NSLog(@"第一次授权失败");
                }
            }];
        } else if (status == SGPermissionStatusAuthorized) {
            NSLog(@"SGPermissionStatusAuthorized");
            [self _enterImagePickerController];
        } else if (status == SGPermissionStatusDenied) {
            NSLog(@"SGPermissionStatusDenied");
            NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
            NSString *app_Name = [infoDict objectForKey:@"CFBundleDisplayName"];
            if (app_Name == nil) {
                app_Name = [infoDict objectForKey:@"CFBundleName"];
            }
            
            NSString *messageString = [NSString stringWithFormat:XTLS(@"AllowAppAccessPhotos"), app_Name];
            UIAlertController *alertC = [UIAlertController alertControllerWithTitle:XTLS(@"Reminder") message:messageString preferredStyle:(UIAlertControllerStyleAlert)];
            UIAlertAction *alertA = [UIAlertAction actionWithTitle:XTLS(@"OK") style:(UIAlertActionStyleDefault) handler:nil];
            
            [alertC addAction:alertA];
            [self presentViewController:alertC animated:YES completion:nil];
        } else if (status == SGPermissionStatusRestricted) {
            NSLog(@"SGPermissionStatusRestricted");
            UIAlertController *alertC = [UIAlertController alertControllerWithTitle:XTLS(@"Reminder") message:XTLS(@"AccessAlbumFailed") preferredStyle:(UIAlertControllerStyleAlert)];
            UIAlertAction *alertA = [UIAlertAction actionWithTitle:XTLS(@"OK") style:(UIAlertActionStyleDefault) handler:nil];
            [alertC addAction:alertA];
            [self presentViewController:alertC animated:YES completion:nil];
        }
    }];
}

- (void)_enterImagePickerController {
    [self stop];

    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.delegate = self;
    imagePicker.modalPresentationStyle = UIModalPresentationCustom;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

#pragma mark - - UIImagePickerControllerDelegate 的方法
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:^{
        [self start];
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    
    __weak typeof(self) weakSelf = self;
    
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [self dismissViewControllerAnimated:YES completion:^{
        [weakSelf detectCodesInImage:image];
    }];
}

#pragma mark - Camera

- (void)requestCameraAccessAndConfigureIfNeeded {
    if (self.session || self.didRequestCameraSetup) {
        return;
    }
    self.didRequestCameraSetup = YES;
    
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) {
        [self configureCaptureSession];
        return;
    }
    
    if (status == AVAuthorizationStatusNotDetermined) {
        __weak typeof(self) weakSelf = self;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) {
                    [weakSelf configureCaptureSession];
                } else {
                    [weakSelf showCameraUnavailableMessage:XTLS(@"XT_No_Camera_Permission_Use_Album")];
                }
            });
        }];
        return;
    }
    
    [self showCameraUnavailableMessage:XTLS(@"XT_No_Camera_Permission_Settings_Use_Album")];
}

- (void)configureCaptureSession {
    if (self.session) {
        [self startSession];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        AVCaptureSession *session = [[AVCaptureSession alloc] init];
        if ([session canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
            session.sessionPreset = AVCaptureSessionPreset1920x1080;
        } else if ([session canSetSessionPreset:AVCaptureSessionPresetHigh]) {
            session.sessionPreset = AVCaptureSessionPresetHigh;
        }
        
        AVCaptureDevice *device = [strongSelf defaultVideoDevice];
        if (!device) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf showCameraUnavailableMessage:XTLS(@"XT_No_Available_Camera_Use_Album")];
            });
            return;
        }
        
        NSError *inputError = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&inputError];
        if (!input || inputError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf showCameraUnavailableMessage:XTLS(@"XT_Camera_Open_Failed_Use_Album")];
            });
            return;
        }
        
        AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
        videoDataOutput.videoSettings = @{
            (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
        };
        [strongSelf configureDeviceForFastScan:device];
        
        [session beginConfiguration];
        if ([session canAddInput:input]) {
            [session addInput:input];
        }
        BOOL didAddMetadataOutput = NO;
        if ([session canAddOutput:metadataOutput]) {
            [session addOutput:metadataOutput];
            didAddMetadataOutput = YES;
        }
        BOOL didAddVideoDataOutput = NO;
        if ([session canAddOutput:videoDataOutput]) {
            [session addOutput:videoDataOutput];
            didAddVideoDataOutput = YES;
        }
        if (didAddMetadataOutput) {
            [metadataOutput setMetadataObjectsDelegate:strongSelf queue:strongSelf.metadataQueue];
            NSArray<AVMetadataObjectType> *metadataTypes = [strongSelf preferredMetadataObjectTypesForOutput:metadataOutput];
            if (metadataTypes.count > 0) {
                metadataOutput.metadataObjectTypes = metadataTypes;
            }
        }
        if (didAddVideoDataOutput) {
            [videoDataOutput setSampleBufferDelegate:strongSelf queue:strongSelf.visionQueue];
        }
        [session commitConfiguration];
        
        if (!didAddMetadataOutput && !didAddVideoDataOutput) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf showCameraUnavailableMessage:XTLS(@"XT_Scan_Start_Failed_Use_Album")];
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) mainSelf = weakSelf;
            if (!mainSelf) {
                return;
            }
            mainSelf.session = session;
            mainSelf.metadataOutput = metadataOutput;
            mainSelf.videoDataOutput = videoDataOutput;
            mainSelf.captureDevice = device;
            [mainSelf installPreviewLayerForSession:session];
            [mainSelf updateRectOfInterest];
            [mainSelf startSession];
        });
    });
}

- (AVCaptureDevice *)defaultVideoDevice {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    if (!device) {
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return device;
}

- (void)configureDeviceForFastScan:(AVCaptureDevice *)device {
    NSError *error = nil;
    if (![device lockForConfiguration:&error]) {
        return;
    }
    
    if (device.isFocusPointOfInterestSupported) {
        device.focusPointOfInterest = CGPointMake(0.5, 0.5);
    }
    if (device.isExposurePointOfInterestSupported) {
        device.exposurePointOfInterest = CGPointMake(0.5, 0.5);
    }
    if (device.isAutoFocusRangeRestrictionSupported) {
        device.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear;
    }
    if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
        device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    }
    if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    }
    if (device.isSmoothAutoFocusSupported) {
        device.smoothAutoFocusEnabled = YES;
    }
    if (device.maxAvailableVideoZoomFactor > 1.0) {
        CGFloat minZoom = MAX(1.0, device.minAvailableVideoZoomFactor);
        CGFloat preferredZoom = MAX(1.0, self.initialZoomFactor);
        CGFloat maxZoom = MIN(MAX(preferredZoom, 2.0), device.maxAvailableVideoZoomFactor);
        device.videoZoomFactor = MIN(MAX(preferredZoom, minZoom), maxZoom);
    }
    
    [device unlockForConfiguration];
}

- (void)installPreviewLayerForSession:(AVCaptureSession *)session {
    [self.previewLayer removeFromSuperlayer];
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    [self updatePreviewOrientation];
}

- (void)startSession {
    AVCaptureSession *session = self.session;
    if (!session || self.foundResult) {
        return;
    }
    
    dispatch_async(self.sessionQueue, ^{
        if (!session.isRunning) {
            [session startRunning];
        }
    });
}

- (void)stopSession {
    AVCaptureSession *session = self.session;
    if (!session) {
        return;
    }
    
    dispatch_async(self.sessionQueue, ^{
        if (session.isRunning) {
            [session stopRunning];
        }
    });
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self stop];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (!self.foundResult) {
        [self start];
    }
}

- (void)showCameraUnavailableMessage:(NSString *)message {
    NSLog(@"%@", message);
}

- (void)updatePreviewOrientation {
    AVCaptureConnection *connection = self.previewLayer.connection;
    if (!connection || !connection.isVideoOrientationSupported) {
        return;
    }
    
    UIInterfaceOrientation interfaceOrientation = self.view.window.windowScene.interfaceOrientation;
    if (interfaceOrientation == UIInterfaceOrientationUnknown) {
        UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
        switch (deviceOrientation) {
            case UIDeviceOrientationLandscapeLeft:
                interfaceOrientation = UIInterfaceOrientationLandscapeRight;
                break;
            case UIDeviceOrientationLandscapeRight:
                interfaceOrientation = UIInterfaceOrientationLandscapeLeft;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                interfaceOrientation = UIInterfaceOrientationPortraitUpsideDown;
                break;
            default:
                interfaceOrientation = UIInterfaceOrientationPortrait;
                break;
        }
    }
    
    CGImagePropertyOrientation visionOrientation = kCGImagePropertyOrientationRight;
    switch (interfaceOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            visionOrientation = kCGImagePropertyOrientationUp;
            break;
        case UIInterfaceOrientationLandscapeRight:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            visionOrientation = kCGImagePropertyOrientationDown;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            visionOrientation = kCGImagePropertyOrientationLeft;
            break;
        default:
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            visionOrientation = kCGImagePropertyOrientationRight;
            break;
    }
    self.cachedVisionOrientation = visionOrientation;
    
    AVCaptureConnection *videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    if (videoConnection.isVideoOrientationSupported) {
        videoConnection.videoOrientation = connection.videoOrientation;
    }
}

- (void)updateRectOfInterest {
    if (!self.metadataOutput) {
        return;
    }
    
    self.metadataOutput.rectOfInterest = CGRectMake(0.0, 0.0, 1.0, 1.0);
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (self.foundResult) {
        return;
    }
    
    for (AVMetadataObject *metadataObject in metadataObjects) {
        if (![metadataObject isKindOfClass:AVMetadataMachineReadableCodeObject.class]) {
            continue;
        }
        
        AVMetadataMachineReadableCodeObject *codeObject = (AVMetadataMachineReadableCodeObject *)metadataObject;
        if (codeObject.stringValue.length > 0) {
            NSString *result = [codeObject.stringValue copy];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self handleDetectedResult:result vibrate:YES];
            });
            break;
        }
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (output != self.videoDataOutput || self.foundResult || self.visionRequestInFlight) {
        return;
    }
    
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastVisionScanTime < self.visionScanInterval) {
        return;
    }
    self.lastVisionScanTime = now;
    self.visionRequestInFlight = YES;
    
    VNDetectBarcodesRequest *request = [[VNDetectBarcodesRequest alloc] init];
    NSArray<VNBarcodeSymbology> *symbologies = [self preferredVisionSymbologiesForRequest:request];
    if (symbologies.count > 0) {
        request.symbologies = symbologies;
    }
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) {
        self.visionRequestInFlight = NO;
        return;
    }
    
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer orientation:self.cachedVisionOrientation options:@{}];
    NSError *error = nil;
    BOOL success = [handler performRequests:@[request] error:&error];
    self.visionRequestInFlight = NO;
    if (!success || error || self.foundResult) {
        return;
    }
    
    NSArray<VNBarcodeObservation *> *results = (NSArray<VNBarcodeObservation *> *)request.results;
    for (VNBarcodeObservation *observation in results) {
        NSString *payload = observation.payloadStringValue;
        if (payload.length == 0) {
            continue;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleDetectedResult:payload vibrate:YES];
        });
        break;
    }
}

#pragma mark - Image recognition

- (void)detectCodesInImage:(UIImage *)image {
    if (!image.CGImage) {
        NSLog(@"图片读取失败");
        [self start];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        VNDetectBarcodesRequest *request = [[VNDetectBarcodesRequest alloc] init];
        NSArray<VNBarcodeSymbology> *symbologies = [weakSelf preferredVisionSymbologiesForRequest:request];
        if (symbologies.count > 0) {
            request.symbologies = symbologies;
        }
        
        CGImagePropertyOrientation orientation = [weakSelf cgImageOrientationFromUIImageOrientation:image.imageOrientation];
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image.CGImage orientation:orientation options:@{}];
        NSError *error = nil;
        BOOL success = [handler performRequests:@[request] error:&error];
        NSArray<VNBarcodeObservation *> *results = (NSArray<VNBarcodeObservation *> *)request.results;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success || error) {
                NSLog(@"图片识别失败");
                [weakSelf start];
                return;
            }
            
            VNBarcodeObservation *bestResult = nil;
            for (VNBarcodeObservation *observation in results) {
                if (observation.payloadStringValue.length > 0) {
                    bestResult = observation;
                    break;
                }
            }
            
            if (!bestResult) {
                NSLog(@"未识别出二维码或条码");
                [weakSelf start];
                return;
            }
            
            [weakSelf handleDetectedResult:bestResult.payloadStringValue vibrate:NO];
        });
    });
}

- (CGImagePropertyOrientation)cgImageOrientationFromUIImageOrientation:(UIImageOrientation)imageOrientation {
    switch (imageOrientation) {
        case UIImageOrientationUp:
            return kCGImagePropertyOrientationUp;
        case UIImageOrientationDown:
            return kCGImagePropertyOrientationDown;
        case UIImageOrientationLeft:
            return kCGImagePropertyOrientationLeft;
        case UIImageOrientationRight:
            return kCGImagePropertyOrientationRight;
        case UIImageOrientationUpMirrored:
            return kCGImagePropertyOrientationUpMirrored;
        case UIImageOrientationDownMirrored:
            return kCGImagePropertyOrientationDownMirrored;
        case UIImageOrientationLeftMirrored:
            return kCGImagePropertyOrientationLeftMirrored;
        case UIImageOrientationRightMirrored:
            return kCGImagePropertyOrientationRightMirrored;
    }
}

#pragma mark - Supported symbologies

- (NSArray<AVMetadataObjectType> *)preferredMetadataObjectTypesForOutput:(AVCaptureMetadataOutput *)output {
    NSArray<AVMetadataObjectType> *preferredTypes = @[
        AVMetadataObjectTypeUPCECode,
        AVMetadataObjectTypeCode39Code,
        AVMetadataObjectTypeCode39Mod43Code,
        AVMetadataObjectTypeEAN13Code,
        AVMetadataObjectTypeEAN8Code,
        AVMetadataObjectTypeCode93Code,
        AVMetadataObjectTypeCode128Code,
        AVMetadataObjectTypePDF417Code,
        AVMetadataObjectTypeQRCode,
        AVMetadataObjectTypeAztecCode,
        AVMetadataObjectTypeInterleaved2of5Code,
        AVMetadataObjectTypeITF14Code,
        AVMetadataObjectTypeDataMatrixCode,
    ];
    
    NSMutableArray<AVMetadataObjectType> *availableTypes = [NSMutableArray array];
    for (AVMetadataObjectType type in preferredTypes) {
        if ([output.availableMetadataObjectTypes containsObject:type]) {
            [availableTypes addObject:type];
        }
    }
    return [availableTypes copy];
}

- (NSArray<VNBarcodeSymbology> *)preferredVisionSymbologiesForRequest:(VNDetectBarcodesRequest *)request {
    NSArray<VNBarcodeSymbology> *supportedSymbologies = nil;
    if (@available(iOS 15.0, *)) {
        supportedSymbologies = [request supportedSymbologiesAndReturnError:nil];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        supportedSymbologies = VNDetectBarcodesRequest.supportedSymbologies;
#pragma clang diagnostic pop
    }
    
    NSArray<VNBarcodeSymbology> *preferredSymbologies = @[
        VNBarcodeSymbologyQR,
        VNBarcodeSymbologyCode128,
    ];
    
    NSMutableArray<VNBarcodeSymbology> *availableSymbologies = [NSMutableArray array];
    for (VNBarcodeSymbology symbology in preferredSymbologies) {
        if ([supportedSymbologies containsObject:symbology]) {
            [availableSymbologies addObject:symbology];
        }
    }
    return [availableSymbologies copy];
}

- (SGScanView *)scanView {
    if (!_scanView) {
        SGScanViewConfigure *configure = [[SGScanViewConfigure alloc] init];
        configure.isShowBorder = YES;
        configure.borderColor = [UIColor clearColor];
        configure.cornerColor = [UIColor whiteColor];
        configure.cornerWidth = 3;
        configure.cornerLength = 15;
        configure.isFromTop = YES;
        configure.scanline = @"SGQRCode.bundle/scan_scanline_qq";
        configure.color = [UIColor clearColor];
        
        CGFloat x = 0;
        CGFloat y = 0;
        CGFloat w = self.view.frame.size.width;
        CGFloat h = self.view.frame.size.height;
        _scanView = [[SGScanView alloc] initWithFrame:CGRectMake(x, y, w, h) configure:configure];
        [_scanView startScanning];
        _scanView.scanFrame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    }
    return _scanView;
}

- (UILabel *)promptLabel {
    if (!_promptLabel) {
        _promptLabel = [[UILabel alloc] init];
        _promptLabel.backgroundColor = [UIColor clearColor];
        CGFloat promptLabelX = 0;
        CGFloat promptLabelY = 0.73 * self.view.frame.size.height;
        CGFloat promptLabelW = self.view.frame.size.width;
        CGFloat promptLabelH = 25;
        _promptLabel.frame = CGRectMake(promptLabelX, promptLabelY, promptLabelW, promptLabelH);
        _promptLabel.textAlignment = NSTextAlignmentCenter;
        _promptLabel.font = [UIFont boldSystemFontOfSize:13.0];
        _promptLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
        _promptLabel.text = XTLS(@"ScanQRInFrame");
    }
    return _promptLabel;
}


@end
