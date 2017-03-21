//
//  KeyboardTrackingViewManager.m
//  ReactNativeChat
//
//  Created by Artal Druk on 19/04/2016.
//  Copyright © 2016 Wix.com All rights reserved.
//

#import "KeyboardTrackingViewManager.h"
#import "ObservingInputAccessoryView.h"
#import "RCTTextView.h"
#import "RCTTextField.h"

@interface KeyboardTrackingView : UIView
{
	ObservingInputAccessoryView* _observingAccessoryView;
}

@property (nonatomic) BOOL trackInteractive;

@end

@implementation KeyboardTrackingView

-(instancetype)init
{
	self = [super init];
	if (self)
	{
		_trackInteractive = NO;
	}
	return self;
}

-(void)dealloc
{
	[self stopTracking];
	
	[self removeObserver:self forKeyPath:@"bounds"];
}

-(void)setTrackInteractive:(BOOL)trackInteractive
{
	_trackInteractive = trackInteractive;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self setInputAccessoryForTextInput:trackInteractive];
	});
}

- (UIView*)observingAccessoryView
{
	if(_observingAccessoryView == nil)
	{
		_observingAccessoryView = [ObservingInputAccessoryView new];
	}
	
	return _observingAccessoryView;
}

- (void)didMoveToWindow
{
	[super didMoveToWindow];
	
	[self startTracking];
	
	[self addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	self.observingAccessoryView.bounds = self.bounds;
}

- (NSArray*)getAllSubviewsForView:(UIView*)view
{
	NSMutableArray *allSubviews = [NSMutableArray new];
	for (UIView *subview in view.subviews)
	{
		[allSubviews addObject:subview];
		[allSubviews addObjectsFromArray:[self getAllSubviewsForView:subview]];
	}
	return allSubviews;
}

-(void)setInputAccessoryForTextInput:(BOOL)startTracking
{
	BOOL registerFrameChangeNotif = NO;
	NSArray *allSubviews = [self getAllSubviewsForView:self];
	
	if(startTracking)
	{
		self.observingAccessoryView.bounds = self.bounds;
	}
	
	for (UIView *subview in allSubviews)
	{
		if ([subview isKindOfClass:[RCTTextField class]])
		{
			UIView *inputAccesorry = startTracking ? self.observingAccessoryView : nil;
			[((RCTTextField*)subview) setInputAccessoryView:inputAccesorry];
			registerFrameChangeNotif = YES;
			break;
		}
		else if ([subview isKindOfClass:[RCTTextView class]])
		{
			UITextView *textView = [subview valueForKey:@"_textView"];
			if (textView != nil)
			{
				UIView *inputAccesorry = startTracking ? self.observingAccessoryView : nil;
				[textView setInputAccessoryView:inputAccesorry];
				registerFrameChangeNotif = YES;
				break;
			}
		}
	}
	
	if (startTracking && registerFrameChangeNotif)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardFrameChangedForView:) name:ObservingInputAccessoryViewFrameDidChangeNotification object:nil];
	}
	else
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:ObservingInputAccessoryViewFrameDidChangeNotification object:nil];
	}
}

-(void)startTracking
{
	NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
	[notifCenter addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[notifCenter addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	
	if (self.trackInteractive)
	{
		[self setInputAccessoryForTextInput:YES];
	}
}

-(void)stopTracking
{
	NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
	[notifCenter removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[notifCenter removeObserver:self name:UIKeyboardWillHideNotification object:nil];
	
	[self setInputAccessoryForTextInput:NO];
}

-(void)animateViewToTrackKeyboard:(NSNotification *)notification keyboardShown:(BOOL)keyboardShown
{
	NSDictionary *info = [notification userInfo];
	NSTimeInterval animationDuration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	
	UIViewAnimationCurve keyboardTransitionAnimationCurve;
	[[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&keyboardTransitionAnimationCurve];
	keyboardTransitionAnimationCurve = keyboardTransitionAnimationCurve<<16;
	
	CGRect keyboardFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
	keyboardFrame.size.height -= self.observingAccessoryView.bounds.size.height;
	
	[UIView animateWithDuration:animationDuration delay:0.0 options:(UIViewAnimationOptions)keyboardTransitionAnimationCurve animations:^
	 {
		 self.transform = keyboardShown ? CGAffineTransformMakeTranslation(0, -keyboardFrame.size.height) : CGAffineTransformIdentity;
	 } completion:nil];
}

-(void)onKeyboardFrameChangedForView:(NSNotification*)notification
{
	CGFloat accessoryTranslation = -(self.window.bounds.size.height - [notification.object doubleValue] - self.observingAccessoryView.bounds.size.height);
	self.transform = CGAffineTransformMakeTranslation(0, accessoryTranslation);
}

- (void)keyboardWillShow:(NSNotification *)notification
{
	[self animateViewToTrackKeyboard:notification keyboardShown:YES];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	[self animateViewToTrackKeyboard:notification keyboardShown:NO];
}

- (void)onKeyboardFrameChanged:(NSNotification *)notification
{
	[self onKeyboardFrameChangedForView:notification.object];
}

@end

@implementation KeyboardTrackingViewManager

RCT_EXPORT_MODULE()

- (UIView *)view
{
	return [[KeyboardTrackingView alloc] init];
}

RCT_CUSTOM_VIEW_PROPERTY(trackInteractive, BOOL, KeyboardTrackingView)
{
	view.trackInteractive = [RCTConvert BOOL:json];
}

@end
