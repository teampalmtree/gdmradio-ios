//
//  ViewController.h
//  GDM
//
//  Created by Daniel Farmer on 1/10/14.
//  Copyright (c) 2014 drayfar. All rights reserved.
//
//  This software is based on code written and shared by Matt Gallagher. The
//  code has been modified from the version accessed on Jan 12, 2014. The
//  original license is copied below:
//
//  Created by Matt Gallagher on 27/09/08.
//  Copyright 2008 Matt Gallagher. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software. Permission is granted to anyone to
//  use this software for any purpose, including commercial applications, and to
//  alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source
//     distribution.
//

#import <UIKit/UIKit.h>

@class AudioStreamer;

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *artistLabel;
@property (weak, nonatomic) IBOutlet UIView *mpVolumeViewParentView;

- (IBAction)togglePlay:(id)sender;

- (void)enterBackground;
- (void)leaveBackground;

@end
