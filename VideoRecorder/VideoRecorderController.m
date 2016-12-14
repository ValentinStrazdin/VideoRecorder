//
//  VideoRecorderController.m
//
//  Created by Valentin Strazdin on 9/25/15.
//  Copyright © 2015 Valentin Strazdin. All rights reserved.
//

#import "VideoRecorderController.h"

#define TOTAL_RECORDING_TIME    60*20	// максимальное время видеозаписи в секундах
#define FRAMES_PER_SECOND       30		// количество кадров в секунду
#define FREE_DISK_SPACE_LIMIT   1024 * 1024	// минимальный размер свободного места (байт)
#define MAX_VIDEO_FILE_SIZE     160 * 1024 * 1024	// максимальный размер видеофайла (байт)
#define CAPTURE_SESSION_PRESET  AVCaptureSessionPreset352x288 //качество видеозаписи

#define BeginVideoRecording     1117	// звук начала записи видео
#define EndVideoRecording       1118	// звук конца записи видео

@interface VideoRecorderController () <AVCaptureFileOutputRecordingDelegate>
{
    BOOL WeAreRecording;	// флаг, определяющий идет ли запись видео
    
    AVCaptureSession *CaptureSession;
    AVCaptureMovieFileOutput *MovieFileOutput;
    AVCaptureDeviceInput *VideoInputDevice;
}

// Эти элементы и методы нужно привязать в дизайнере интерфейса
@property (retain) IBOutlet UILabel *timeLabel; 	// индикатор времени записи на верхней панели
@property (retain) IBOutlet UIButton *startButton; 	// кнопка Start / Stop
@property (retain) IBOutlet UIImageView *circleImage;  // кружок вокруг кнопки Start
@property (retain) IBOutlet UIButton *cancelButton;      // кнопка Cancel
@property (retain) IBOutlet UIButton *useVideoButton; // кнопка Use Video
@property (retain) IBOutlet UIView *bottomView;	       // нижняя панель
@property (retain) IBOutlet UIButton *playVideoButton; // кнопка Play Video

- (IBAction)startStopButtonPressed:(id)sender;	 // обработчик нажатия кнопки Start / Stop
- (IBAction)cancel:(id)sender;			 // обработчик нажатия кнопки  Cancel
- (IBAction)useVideo:(id)sender;			// обработчик нажатия кнопки  Use Video
- (IBAction)playVideo:(id)sender;			// обработчик нажатия кнопки  Play Video

@property (retain) AVCaptureVideoPreviewLayer *PreviewLayer;

// таймер и время для индикатора времени записи
@property (retain) NSTimer *videoTimer;
@property (assign) NSTimeInterval elapsedTime;

@end

@implementation VideoRecorderController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.outputPath = [[NSString alloc] initWithFormat:@"%@%@", NSTemporaryDirectory(), @"output.mov"];
    [self deleteVideoFile];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(applicationDidEnterBackground:)
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
    CaptureSession = [[AVCaptureSession alloc] init];
    AVCaptureDevice *VideoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (VideoDevice) {
        NSError *error = nil;
        VideoInputDevice = [AVCaptureDeviceInput deviceInputWithDevice:VideoDevice error:&error];
        if (!error) {
            [CaptureSession beginConfiguration];
            if ([CaptureSession canAddInput:VideoInputDevice]) {
                [CaptureSession addInput:VideoInputDevice];
            }
            [CaptureSession commitConfiguration];
        }
    }
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    NSError *error = nil;
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (audioInput) {
        [CaptureSession addInput:audioInput];
    }
    [self setPreviewLayer:[[AVCaptureVideoPreviewLayer alloc] initWithSession:CaptureSession]];
    [self.PreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [self setupLayoutInRect:[[[self view] layer] bounds]];
    UIView *CameraView = [[UIView alloc] init];
    [[self view] addSubview:CameraView];
    [self.view sendSubviewToBack:CameraView];
    [[CameraView layer] addSublayer:self.PreviewLayer];
    MovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    CMTime maxDuration = CMTimeMakeWithSeconds(TOTAL_RECORDING_TIME, FRAMES_PER_SECOND);
    MovieFileOutput.maxRecordedDuration = maxDuration;
    MovieFileOutput.maxRecordedFileSize = MAX_VIDEO_FILE_SIZE;
    MovieFileOutput.minFreeDiskSpaceLimit = FREE_DISK_SPACE_LIMIT;
    if ([CaptureSession canAddOutput:MovieFileOutput]) {
        [CaptureSession addOutput:MovieFileOutput];
    }
    if ([CaptureSession canSetSessionPreset:CAPTURE_SESSION_PRESET]) {
        [CaptureSession setSessionPreset:CAPTURE_SESSION_PRESET];
    }
    [self cameraSetOutputProperties];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    if (WeAreRecording) {
        [self stopRecording];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.outputPath]) {
        // Если мы вернулись на экран после просмотра видео, то нам не нужно запускать AVCaptureSession
        WeAreRecording = NO;
        [CaptureSession startRunning];
    }
}

- (BOOL)shouldAutorotate {
    return (CaptureSession.isRunning && !WeAreRecording);
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscape | UIInterfaceOrientationMaskPortraitUpsideDown);
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self setupLayoutInRect:CGRectMake(0, 0, size.width, size.height)];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self cameraSetOutputProperties];
    }];
}

// Этот метод выставляет правильную ориентацию файла видео выхода и слоя просмотра
// Он аналогичен viewWillTransitionToSize, нужен для поддержки версий iOS 7 и более ранних
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self setupLayoutInRect:[[[self view] layer] bounds]];
    [self cameraSetOutputProperties];
}

// Пересчитываем размеры слоя просмотра в зависимости от ориентации устройства
- (void)setupLayoutInRect:(CGRect)layoutRect {
    [self.PreviewLayer setBounds:layoutRect];
    [self.PreviewLayer setPosition:CGPointMake(CGRectGetMidX(layoutRect),  CGRectGetMidY(layoutRect))];
}

// Выставляем правильную ориентацию файла видео выхода и слоя просмотра
- (void)cameraSetOutputProperties {
    AVCaptureConnection *videoConnection = nil;
    for ( AVCaptureConnection *connection in [MovieFileOutput connections] ) {
        for ( AVCaptureInputPort *port in [connection inputPorts] ) {
            if ( [[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
            }
        }
    }
    
    if ([videoConnection isVideoOrientationSupported]) {
        if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) {
            self.PreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
        }
        else if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown) {
            self.PreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
        }
        else if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationLandscapeLeft) {
            self.PreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            [videoConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
        }
        else {
            self.PreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            [videoConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
        }
    }
}

- (IBAction)startStopButtonPressed:(id)sender {
    if (!WeAreRecording) {
        [self startRecording];
    }
    else {
        [self stopRecording];
    }
}

- (IBAction)cancel:(id)sender {
    if ([CaptureSession isRunning]) {
        if (self.delegate) {
            [self.delegate videoRecorderDidCancelRecordingVideo];
        }
    }
    else {
        self.circleImage.hidden = NO;
        self.startButton.hidden = NO;
        self.useVideoButton.hidden = YES;
        self.playVideoButton.hidden = YES;
        [self.cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
        self.timeLabel.text = @"00:00";
        self.elapsedTime = 0;
        [CaptureSession startRunning];
    }
}

- (IBAction)useVideo:(id)sender {
    if (self.delegate) {
        [self.delegate videoRecorderDidFinishRecordingVideoWithOutputPath:self.outputPath];
    }
}

- (IBAction)playVideo:(id)sender {
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputPath]) {
        NSURL *outputFileURL = [[NSURL alloc] initFileURLWithPath:self.outputPath];
        AVPlayer *player = [AVPlayer playerWithURL:outputFileURL];
        AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
        [self presentViewController:controller animated:YES completion:nil];
        controller.player = player;
        controller.allowsPictureInPicturePlayback = NO;
        [player play];
    }
}

// Это начало записи видео
- (void)startRecording {
    // Проигрываем звук начала записи видео
    AudioServicesPlaySystemSound(BeginVideoRecording);
    WeAreRecording = YES;
    [self.cancelButton setHidden:YES];
    [self.bottomView setHidden:YES];
    [self.startButton setImage:[UIImage imageNamed:@"StopVideo"] forState:UIControlStateNormal];
    self.timeLabel.text = @"00:00";
    self.elapsedTime = 0;
    self.videoTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateTime) userInfo:nil repeats:YES];
    // Удаляем файл видеозаписи, если он существует, чтобы начать запись по новой
    [self deleteVideoFile];
    
    // Начинаем запись в файл видеозаписи
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:self.outputPath];
    [MovieFileOutput startRecordingToOutputFileURL:outputURL recordingDelegate:self];
}

- (void)deleteVideoFile {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:self.outputPath]) {
        NSError *error = nil;
        if ([fileManager removeItemAtPath:self.outputPath error:&error] == NO) {
            // Обработчик ошибки удаления файла
        }
    }
}

// Это конец записи видео
- (void)stopRecording {
    // Проигрываем звук конца записи видео
    AudioServicesPlaySystemSound(EndVideoRecording);
    WeAreRecording = NO;
    [CaptureSession stopRunning];
    self.circleImage.hidden = YES;
    self.startButton.hidden = YES;
    [self.cancelButton setTitle:@"Retake" forState:UIControlStateNormal];
    [self.cancelButton setHidden:NO];
    [self.bottomView setHidden:NO];
    [self.startButton setImage:[UIImage imageNamed:@"StartVideo"] forState:UIControlStateNormal];
    // останавливаем таймер видеозаписи
    [self.videoTimer invalidate];
    self.videoTimer = nil;
    
    // Заканчиваем запись в файл видеозаписи
    [MovieFileOutput stopRecording];
}

- (void)updateTime {
    self.elapsedTime += self.videoTimer.timeInterval;
    NSInteger seconds = (NSInteger)self.elapsedTime % 60;
    NSInteger minutes = ((NSInteger)self.elapsedTime / 60) % 60;
    self.timeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
      fromConnections:(NSArray *)connections
                error:(NSError *)error {
    if (WeAreRecording) {
        [self stopRecording];
    }
    
    BOOL RecordedSuccessfully = YES;
    if ([error code] != noErr) {
        // Если при записи видео произошла ошибка, но файл был успешно сохранен,
        // то мы все равно считаем, что запись прошла успешно
        id value = [[error userInfo] objectForKey:AVErrorRecordingSuccessfullyFinishedKey];
        if (value != nil) {
            RecordedSuccessfully = [value boolValue];
        }
    }
    if (RecordedSuccessfully) {
        // Если запись прошла успешно, мы показываем кнопку Use Video
        self.useVideoButton.hidden = NO;
        self.playVideoButton.hidden = NO;
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    CaptureSession = nil;
    MovieFileOutput = nil;
    VideoInputDevice = nil;
}
@end
