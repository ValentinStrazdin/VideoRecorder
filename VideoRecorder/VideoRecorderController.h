//
//  VideoRecorderController.h
//
//  Created by Valentin Strazdin on 9/25/15.
//  Copyright © 2015 Valentin Strazdin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVKit/AVKit.h>

@protocol VideoRecorderDelegate <NSObject>
// метод делегата, срабатывает при успешном завершении видеозаписи
- (void)videoRecorderDidFinishRecordingVideoWithOutputPath:(NSString *)outputPath;
// метод делегата, срабатывает при отмене видеозаписи
- (void)videoRecorderDidCancelRecordingVideo;
@end

@interface VideoRecorderController : UIViewController

@property (nonatomic, retain) NSString *outputPath;		// путь к файлу видеозаписи
@property (nonatomic, assign) id<VideoRecorderDelegate> delegate;

@end
