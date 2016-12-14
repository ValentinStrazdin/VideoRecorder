//
//  ViewController.m
//  VideoRecorder
//
//  Created by Valentin Strazdin on 10/22/15.
//  Copyright © 2015 Valentin Strazdin. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

- (IBAction)startRecording:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.saveVideoToPhotoLibrary = YES;
    // Do any additional setup after loading the view.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startRecording:(id)sender {
    UIStoryboard *storyboardVideoRecorder = [UIStoryboard storyboardWithName:@"VideoRecorder" bundle:nil];
    VideoRecorderController *videoRecorder = [storyboardVideoRecorder instantiateInitialViewController];
    videoRecorder.delegate = self;
    
    [self presentViewController:videoRecorder animated:YES completion:nil];
}

- (void)videoRecorderDidFinishRecordingVideoWithOutputPath:(NSString *)outputPath {
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:^{
            if (self.saveVideoToPhotoLibrary) {
                UISaveVideoAtPathToSavedPhotosAlbum(outputPath, nil, nil, nil);
            }
            // Here we display message to user
            NSURL *outputFileURL = [[NSURL alloc] initFileURLWithPath:outputPath];
            NSData *fileData = [NSData dataWithContentsOfURL:outputFileURL];
            NSString *theMessage = [NSString stringWithFormat:@"Video was recorded. File size - %ld kB", (unsigned long)(fileData.length / (1024))];
            
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Video Recorder" message:theMessage preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:ac animated:YES completion:nil];
        }];
    }
}

- (void)videoRecorderDidCancelRecordingVideo {
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:^{
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Video Recorder" message:@"Video recording was cancelled" preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:ac animated:YES completion:nil];
        }];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
