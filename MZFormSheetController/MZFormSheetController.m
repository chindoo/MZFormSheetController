//
//  MZFormSheetController.m
//  MZFormSheetController
//
//  Created by Michał Zaborowski on 08.08.2013.
//  Copyright (c) 2013 Michał Zaborowski. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "MZFormSheetController.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

NSString *const MZFormSheetDidPresentNotification = @"MZFormSheetDidPresentNotification";
NSString *const MZFormSheetDidDismissNotification = @"MZFormSheetDidDismissNotification";
NSString *const MZFormSheetWillPresentNotification = @"MZFormSheetWillPresentNotification";
NSString *const MZFormSheetWillDismissNotification = @"MZFormSheetWillDismissNotification";

CGFloat const MZFormSheetControllerDefaultPortraitTopInset = 66.0;
CGFloat const MZFormSheetControllerDefaultLandscapeTopInset = 6.0;
CGFloat const MZFormSheetControllerDefaultWidth = 284.0;
CGFloat const MZFormSheetControllerDefaultHeight = 284.0;

CGFloat const MZFormSheetControllerDefaultAnimationDuration = 0.3;
CGFloat const MZFormSheetControllerDefaultTransitionBounceDuration = 0.5;
CGFloat const MZFormSheetControllerDefaultTransitionDropDownDuration = 0.4;

CGFloat const MZFormSheetPresentedControllerCornerRadius = 6.0;
CGFloat const MZFormSheetPresentedControllerShadowRadius = 6.0;
CGFloat const MZFormSheetPresentedControllerShadowOpacity = 0.5;

UIWindowLevel const UIWindowLevelFormSheet = 1996.0;  // don't overlap system's alert
UIWindowLevel const UIWindowLevelFormSheetBackground = 1995.0; // below the alert window

@class MZFormSheetBackgroundWindow;

static MZFormSheetBackgroundWindow *instanceOfFormSheetBackgroundWindow;
static NSMutableArray *instanceOfSharedQueue;
static BOOL instanceOfFormSheetAnimating;

#pragma mark - MZFormSheetBackgroundWindow

@interface MZFormSheetBackgroundWindow : UIWindow

+ (void)showBackgroundWindowAnimated:(BOOL)animated;
+ (void)hideBackgroundWindowAnimated:(BOOL)animated;

@end

@implementation MZFormSheetBackgroundWindow

+ (void)showBackgroundWindowAnimated:(BOOL)animated
{
    if (!instanceOfFormSheetBackgroundWindow) {
        instanceOfFormSheetBackgroundWindow = [[MZFormSheetBackgroundWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [instanceOfFormSheetBackgroundWindow makeKeyAndVisible];
        instanceOfFormSheetBackgroundWindow.alpha = 0;
        if (animated) {
            [UIView animateWithDuration:MZFormSheetControllerDefaultAnimationDuration
                             animations:^{
                                 instanceOfFormSheetBackgroundWindow.alpha = 1;
                             }];
        } else {
            instanceOfFormSheetBackgroundWindow.alpha = 1;
        }
        
    }
}

+ (void)hideBackgroundWindowAnimated:(BOOL)animated
{
    if (!animated) {
        [instanceOfFormSheetBackgroundWindow removeFromSuperview];
        instanceOfFormSheetBackgroundWindow = nil;
        return;
    }
    [UIView animateWithDuration:MZFormSheetControllerDefaultAnimationDuration
                     animations:^{
                         instanceOfFormSheetBackgroundWindow.alpha = 0;
                     }
                     completion:^(BOOL finished) {
                         [instanceOfFormSheetBackgroundWindow removeFromSuperview];
                         instanceOfFormSheetBackgroundWindow = nil;
                     }];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.opaque = NO;
        self.windowLevel = UIWindowLevelFormSheetBackground;
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0 alpha:0.5] set];
    CGContextFillRect(context, self.bounds);
}

@end

#pragma mark - MZFormSheetController

@interface MZFormSheetController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIViewController *presentedFSViewController;

@property (nonatomic, strong) UIWindow *applicationKeyWindow;
@property (nonatomic, strong) UIWindow *formSheetWindow;
@end

@implementation MZFormSheetController

#pragma mark - Class methods

+ (void)setAnimating:(BOOL)animating
{
    instanceOfFormSheetAnimating = animating;
}

+ (BOOL)isAnimating
{
    return instanceOfFormSheetAnimating;
}

+ (NSMutableArray *)sharedQueue
{
    if (!instanceOfSharedQueue) {
        instanceOfSharedQueue = [NSMutableArray array];
    }
    return instanceOfSharedQueue;
}

#pragma mark - Setters

- (void)setShadowOpacity:(CGFloat)shadowOpacity
{  
    if (_shadowOpacity != shadowOpacity) {
        _shadowOpacity = shadowOpacity;
        self.view.layer.shadowOpacity = _shadowOpacity;
    }
}

- (void)setShadowRadius:(CGFloat)shadowRadius
{
    if (_shadowRadius != shadowRadius) {
        _shadowRadius = shadowRadius;
        self.view.layer.shadowRadius = _shadowRadius;
    }   
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    if (_cornerRadius != cornerRadius) {
        _cornerRadius = cornerRadius;
        self.presentedFSViewController.view.layer.cornerRadius = _cornerRadius;
    }
}

#pragma mark - Getters

- (UIWindow *)formSheetWindow
{
    if (!_formSheetWindow) {
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        window.opaque = NO;
        window.windowLevel = UIWindowLevelFormSheet;
        window.rootViewController = self;
        self.formSheetWindow = window;
    }
    
    return _formSheetWindow;
}

#pragma mark - Public

- (instancetype)initWithViewController:(UIViewController *)presentedFormSheetViewController
{
    if (self = [super init]) {
        self.presentedFSViewController = presentedFormSheetViewController;
        self.presentedFormSheetSize = CGSizeMake(MZFormSheetControllerDefaultWidth, MZFormSheetControllerDefaultHeight);
        
        _cornerRadius = MZFormSheetPresentedControllerCornerRadius;
        _shadowOpacity = MZFormSheetPresentedControllerShadowOpacity;
        _shadowRadius = MZFormSheetPresentedControllerShadowRadius;
        _portraitTopInset = MZFormSheetControllerDefaultPortraitTopInset;
        _landscapeTopInset = MZFormSheetControllerDefaultLandscapeTopInset;
    }
    return self;
}

- (instancetype)initWithSize:(CGSize)formSheetSize viewController:(UIViewController *)presentedFormSheetViewController
{
    if (self = [self initWithViewController:presentedFormSheetViewController]) {
        if (!CGSizeEqualToSize(formSheetSize, CGSizeZero)) {
            self.presentedFormSheetSize = formSheetSize;
        } 
    }
    return self;
}


- (void)presentWithCompletionHandler:(MZFormSheetCompletionHandler)completionHandler
{
    NSAssert(self.presentedFSViewController, @"MZFormSheetController must have at least one view controller.");
    NSAssert(![MZFormSheetController isAnimating], @"Attempting to begin a form sheet transition from to while a transition is already in progress. Wait for didPresentCompletionHandler/didDismissCompletionHandler to know the current transition has completed");
    
    if (completionHandler) {
        self.didPresentCompletionHandler = completionHandler;
    }
    
    self.applicationKeyWindow = [UIApplication sharedApplication].keyWindow;
    
    if (![[MZFormSheetController sharedQueue] containsObject:self]) {
        [[MZFormSheetController sharedQueue] addObject:self];
    }

    [MZFormSheetController setAnimating:YES];
    
    [MZFormSheetBackgroundWindow showBackgroundWindowAnimated:YES];
    
    [self.formSheetWindow makeKeyAndVisible];
    
    [self setupPresentedFSViewControllerFrame];
    
    if (self.willPresentCompletionHandler) {
        self.willPresentCompletionHandler();
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:MZFormSheetWillPresentNotification object:self userInfo:nil];
    
    [self transitionEntryWithCompletionBlock:^{
        [MZFormSheetController setAnimating:NO];
        
        if (self.didPresentCompletionHandler) {
            self.didPresentCompletionHandler();
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:MZFormSheetDidPresentNotification object:self userInfo:nil];
        
    }];
    
}

- (void)dismissWithCompletionHandler:(MZFormSheetCompletionHandler)completionHandler
{
    if (completionHandler) {
        self.didDismissCompletionHandler = completionHandler;
    }
    
    if (self.willDismissCompletionHandler) {
        self.willDismissCompletionHandler();
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:MZFormSheetWillDismissNotification object:self userInfo:nil];
    
    [MZFormSheetController setAnimating:YES];
    
    [[MZFormSheetController sharedQueue] removeObject:self];
    
    if ([MZFormSheetController sharedQueue].count == 0) {
        [MZFormSheetBackgroundWindow hideBackgroundWindowAnimated:YES];
    }
    
    [self transitionOutWithCompletionBlock:^{
        [self cleanup];
        
        [MZFormSheetController setAnimating:NO];
        
        if (self.didDismissCompletionHandler) {
            self.didDismissCompletionHandler();
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:MZFormSheetDidDismissNotification object:self userInfo:nil];
        
    }];
    
    [self.applicationKeyWindow makeKeyWindow];
    self.applicationKeyWindow.hidden = NO;
    
}

//  Created by Kevin Cao on 13/4/29.
//  Copyright (c) 2013 Sumi Interactive
//  Modified by Michał Zaborowski.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#pragma mark - Transitions

- (void)transitionEntryWithCompletionBlock:(void(^)())completionBlock
{
    switch (self.transitionStyle) {
        case MZFormSheetTransitionStyleSlideFromTop:
        {
            CGRect formSheetRect = self.presentedFSViewController.view.frame;
            CGRect originalFormSheetRect = formSheetRect;
            formSheetRect.origin.y = -formSheetRect.size.height;
            self.presentedFSViewController.view.frame = formSheetRect;
            [UIView animateWithDuration:MZFormSheetControllerDefaultAnimationDuration
                             animations:^{
                                 self.presentedFSViewController.view.frame = originalFormSheetRect;
                             }
                             completion:^(BOOL finished) {
                                 if (completionBlock) {
                                     completionBlock();
                                 }
                             }];
        }break;
            
        case MZFormSheetTransitionStyleSlideFromBottom:
        {
            CGRect formSheetRect = self.presentedFSViewController.view.frame;
            CGRect originalFormSheetRect = formSheetRect;
            formSheetRect.origin.y = self.view.bounds.size.height;
            self.presentedFSViewController.view.frame = formSheetRect;
            [UIView animateWithDuration:MZFormSheetControllerDefaultAnimationDuration
                             animations:^{
                                 self.presentedFSViewController.view.frame = originalFormSheetRect;
                             }
                             completion:^(BOOL finished) {
                                 if (completionBlock) {
                                     completionBlock();
                                 }
                             }];
        }break;
        
        case MZFormSheetTransitionStyleFade:
        {
            self.presentedFSViewController.view.alpha = 0;
            [UIView animateWithDuration:MZFormSheetControllerDefaultAnimationDuration
                             animations:^{
                                 self.presentedFSViewController.view.alpha = 1;
                             }
                             completion:^(BOOL finished) {
                                 if (completionBlock) {
                                     completionBlock();
                                 }
                             }];
        }break;
            
        case MZFormSheetTransitionStyleBounce:
        {
            CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
            animation.values = @[@(0.01), @(1.2), @(0.9), @(1)];
            animation.keyTimes = @[@(0), @(0.4), @(0.6), @(1)];
            animation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            animation.duration = MZFormSheetControllerDefaultTransitionBounceDuration;
            animation.delegate = self;
            [animation setValue:completionBlock forKey:@"completionHandler"];
            [self.presentedFSViewController.view.layer addAnimation:animation forKey:@"bouce"];
        }break;
            
        case MZFormSheetTransitionStyleDropDown:
        {
            CGFloat y = self.presentedFSViewController.view.center.y;
            CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position.y"];
            animation.values = @[@(y - self.view.bounds.size.height), @(y + 20), @(y - 10), @(y)];
            animation.keyTimes = @[@(0), @(0.5), @(0.75), @(1)];
            animation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            animation.duration = MZFormSheetControllerDefaultTransitionDropDownDuration;
            animation.delegate = self;
            [animation setValue:completionBlock forKey:@"completionHandler"];
            [self.presentedFSViewController.view.layer addAnimation:animation forKey:@"dropdown"];
        }break;
            
        case MZFormSheetTransitionStyleCustom:
        {
            [self customTransitionEntryWithCompletionBlock:completionBlock];
            
        }break;
        
        case MZFormSheetTransitionStyleNone:
        default:{
            if (completionBlock) {
                completionBlock();
            }
        }break;
    }
}

- (void)transitionOutWithCompletionBlock:(void(^)())completionBlock
{
    switch (self.transitionStyle) {
        case MZFormSheetTransitionStyleSlideFromTop:
        {
            CGRect formSheetRect = self.presentedFSViewController.view.frame;
            formSheetRect.origin.y = -self.view.bounds.size.height;
            [UIView animateWithDuration:MZFormSheetControllerDefaultAnimationDuration
                             animations:^{
                                 self.presentedFSViewController.view.frame = formSheetRect;
                             }
                             completion:^(BOOL finished) {
                                 if (completionBlock) {
                                     completionBlock();
                                 }
                             }];
        }break;
            
        case MZFormSheetTransitionStyleSlideFromBottom:
        {
            CGRect formSheetRect = self.presentedFSViewController.view.frame;
            formSheetRect.origin.y = self.view.bounds.size.height;
            [UIView animateWithDuration:MZFormSheetControllerDefaultAnimationDuration
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                                 self.presentedFSViewController.view.frame = formSheetRect;
                             }
                             completion:^(BOOL finished) {
                                 if (completionBlock) {
                                     completionBlock();
                                 }
                             }];
        }break;
            
        case MZFormSheetTransitionStyleFade:
        {
            [UIView animateWithDuration:MZFormSheetControllerDefaultAnimationDuration
                             animations:^{
                                 self.presentedFSViewController.view.alpha = 0;
                             }
                             completion:^(BOOL finished) {
                                 if (completionBlock) {
                                     completionBlock();
                                 }
                             }];
        }break;
            
        case MZFormSheetTransitionStyleBounce:
        {
            CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
            animation.values = @[@(1), @(1.2), @(0.01)];
            animation.keyTimes = @[@(0), @(0.4), @(1)];
            animation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            animation.duration = MZFormSheetControllerDefaultAnimationDuration;
            animation.delegate = self;
            [animation setValue:completionBlock forKey:@"completionHandler"];
            [self.presentedFSViewController.view.layer addAnimation:animation forKey:@"bounce"];
            
            self.presentedFSViewController.view.transform = CGAffineTransformMakeScale(0.01, 0.01);
        }break;
            
        case MZFormSheetTransitionStyleDropDown:
        {
            CGPoint point = self.presentedFSViewController.view.center;
            point.y += self.view.bounds.size.height;
            [UIView animateWithDuration:MZFormSheetControllerDefaultAnimationDuration
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                                 self.presentedFSViewController.view.center = point;
                                 CGFloat angle = ((CGFloat)arc4random_uniform(100) - 50.f) / 100.f;
                                 self.presentedFSViewController.view.transform = CGAffineTransformMakeRotation(angle);
                             }
                             completion:^(BOOL finished) {
                                 if (completionBlock) {
                                     completionBlock();
                                 }
                             }];
        }break;
        
        case MZFormSheetTransitionStyleCustom:
        {
            [self customTransitionOutWithCompletionBlock:completionBlock];
            
        }break;
            
        case MZFormSheetTransitionStyleNone:
        default:{
            if (completionBlock) {
                completionBlock();
            }
        }break;
    }
}

- (void)customTransitionEntryWithCompletionBlock:(MZFormSheetCompletionHandler)completionBlock
{
    if (completionBlock) {
        completionBlock();
    }
}
- (void)customTransitionOutWithCompletionBlock:(MZFormSheetCompletionHandler)completionBlock
{
    if (completionBlock) {
        completionBlock();
    }
}

- (void)resetTransition
{
    [self.presentedFSViewController.view.layer removeAllAnimations];
}

#pragma mark - CAAnimation delegate

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    void(^completionHandler)(void) = [anim valueForKey:@"completionHandler"];
    if (completionHandler) {
        completionHandler();
    }
}

/////////////////////////////////////////////////////////////////////////////

#pragma mark - Setup

- (void)setupFormSheetViewController
{
    self.presentedFSViewController.view.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    self.presentedFSViewController.view.frame = CGRectMake(0, 0, self.presentedFormSheetSize.width, self.presentedFormSheetSize.height);
    self.presentedFSViewController.view.center = CGPointMake(CGRectGetMidX(self.view.bounds), self.presentedFSViewController.view.center.y);
    self.presentedFSViewController.view.layer.cornerRadius = self.cornerRadius;
    self.presentedFSViewController.view.layer.masksToBounds = YES;
    
    self.view.layer.shadowOffset = CGSizeZero;
    self.view.layer.shadowRadius = self.shadowRadius;
    self.view.layer.shadowOpacity = self.shadowOpacity;
    self.view.frame = self.presentedFSViewController.view.frame;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(handleTapGestureRecognizer:)];
    tapGesture.delegate = self;
    [self.formSheetWindow addGestureRecognizer:tapGesture];
    
    [self.view addSubview:self.presentedFSViewController.view];
}

- (void)setupPresentedFSViewControllerFrame
{
    if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        self.presentedFSViewController.view.frame = CGRectMake(self.presentedFSViewController.view.frame.origin.x, self.portraitTopInset, self.presentedFSViewController.view.frame.size.width, self.presentedFSViewController.view.frame.size.height);
    } else {
        self.presentedFSViewController.view.frame = CGRectMake(self.presentedFSViewController.view.frame.origin.x, self.landscapeTopInset, self.presentedFSViewController.view.frame.size.width, self.presentedFSViewController.view.frame.size.height);
    }
}

#pragma mark - UIGestureRecognizers

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    // recive touch only on background window
    if (touch.view == self.view) {
        return YES;
    }
    return NO;
}

- (void)handleTapGestureRecognizer:(UITapGestureRecognizer *)tapGesture
{
    // If last form sheet controller will begin dismiss, don't want to recive touch
    if (tapGesture.state == UIGestureRecognizerStateEnded && [MZFormSheetController sharedQueue].count > 0){
        CGPoint location = [tapGesture locationInView:[tapGesture.view superview]];
        if (self.didTapOnBackgroundViewCompletionHandler) {
            self.didTapOnBackgroundViewCompletionHandler(location);
        }
        if (self.shouldDismissOnBackgroundViewTap) {
            [self dismissWithCompletionHandler:nil];
        }
    }
}

#pragma mark - View life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupFormSheetViewController];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self setupPresentedFSViewControllerFrame];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self resetTransition];
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (void)cleanup
{
    [self.presentedFSViewController.view removeFromSuperview];
    self.presentedFSViewController = nil;
    
    self.formSheetWindow.rootViewController = nil;
    [self.formSheetWindow removeFromSuperview];
    self.formSheetWindow = nil;
}

@end

#pragma mark - UIViewController (MZFormSheet)

static const char* formSheetControllerKey = "MZFormSheetController";

@implementation UIViewController (MZFormSheet)
@dynamic formSheetController;

#pragma mark - objc_associations

- (MZFormSheetController *)formSheetController
{
    return objc_getAssociatedObject(self, formSheetControllerKey);
}

- (void)setFormSheetController:(MZFormSheetController *)formSheetController
{
    objc_setAssociatedObject(self, formSheetControllerKey, formSheetController, OBJC_ASSOCIATION_ASSIGN);
}

#pragma mark - Public

- (void)presentFormSheetWithViewController:(UIViewController *)viewController completionHandler:(MZFormSheetPresentationCompletionHandler)completionHandler
{
    MZFormSheetController *formSheet = [[MZFormSheetController alloc] initWithViewController:viewController];
    self.formSheetController = formSheet;
    viewController.formSheetController = formSheet;

    [formSheet presentWithCompletionHandler:^{
        if (completionHandler) {
            completionHandler(formSheet);
        }
    }];
}

- (void)dismissFormSheetControllerWithCompletionHandler:(MZFormSheetPresentationCompletionHandler)completionHandler
{
    MZFormSheetController *formSheetController = nil;
    
    if (self.formSheetController) {
        formSheetController = self.formSheetController;
    } else {
        formSheetController = [[MZFormSheetController sharedQueue] lastObject];
    }
    
    [formSheetController dismissWithCompletionHandler:^{
        if (completionHandler) {
            completionHandler(formSheetController);
        }
    }];
}

@end
