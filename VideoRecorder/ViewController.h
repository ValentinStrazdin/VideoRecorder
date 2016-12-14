//
//  ViewController.h
//  VideoRecorder
//
//  Created by Valentin Strazdin on 10/22/15.
//  Copyright © 2015 Valentin Strazdin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoRecorderController.h"
#import <AssetsLibrary/AssetsLibrary.h>		//<<Can delete if not storing videos to the photo library.  Delete the assetslibrary framework too requires this)

@interface ViewController : UIViewController <VideoRecorderDelegate>

@property (nonatomic) BOOL saveVideoToPhotoLibrary;

@end
