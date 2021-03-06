#import "OakTransitionViewController.h"

@interface OakTransitionViewController ()
{
	NSUInteger                    _animationCounter;
	NSArray<NSLayoutConstraint*>* _viewFrameConstraints;
	NSMutableArray<NSView*>*      _hostedSubviews;
	NSView*                       _currentSubview;
}
@end

@implementation OakTransitionViewController
- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
	if(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
	{
		_hostedSubviews = [NSMutableArray array];
	}
	return self;
}

- (void)loadView
{
	self.view = [[NSView alloc] initWithFrame:NSZeroRect];
	_viewFrameConstraints = @[
		[self.view.heightAnchor constraintEqualToConstant:0]
	];
	[NSLayoutConstraint activateConstraints:_viewFrameConstraints];
}

- (void)transitionToView:(NSView*)newView
{
	if(newView == _currentSubview)
		return;

	NSWindow* window = self.view.window;
	if([window.firstResponder isKindOfClass:[NSView class]] && _currentSubview && [(NSView*)window.firstResponder isDescendantOf:_currentSubview])
		[window makeFirstResponder:window];

	if(newView)
	{
		if(NSEqualSizes(NSZeroSize, newView.frame.size))
			newView.frame = { .size = newView.fittingSize };

		newView.translatesAutoresizingMaskIntoConstraints = NO;
		newView.wantsLayer = YES;
		newView.alphaValue = 0;

		[self.view addSubview:newView];
		self.view.nextKeyView = newView;

		[_hostedSubviews addObject:newView];
	}

	NSSize oldSize  = self.view.frame.size;
	NSSize newSize  = newView ? newView.frame.size : NSMakeSize(oldSize.width, 0);
	NSRect newFrame = NSOffsetRect(NSInsetRect(window.frame, (oldSize.width - newSize.width) / 2, (oldSize.height - newSize.height) / 2), (newSize.width - oldSize.width) / 2, (oldSize.height - newSize.height) / 2);

	NSRect screenFrame = (self.view.window.screen ?: NSScreen.mainScreen).visibleFrame;
	if(NSMinX(newFrame) < NSMinX(screenFrame))
		newFrame.origin.x += NSMinX(screenFrame) - NSMinX(newFrame);
	else if(NSMaxX(newFrame) > NSMaxX(screenFrame))
		newFrame.origin.x -= NSMaxX(newFrame) - NSMaxX(screenFrame);
	if(NSMinY(newFrame) < NSMinY(screenFrame))
		newFrame.origin.y += NSMinY(screenFrame) - NSMinY(newFrame);
	else if(NSMaxY(newFrame) > NSMaxY(screenFrame))
		newFrame.origin.y -= NSMaxY(newFrame) - NSMaxY(screenFrame);
	newFrame = NSIntersectionRect(newFrame, screenFrame);

	NSMutableArray* viewFrameConstraints = [NSMutableArray array];
	for(NSView* view in _hostedSubviews)
	{
		[viewFrameConstraints addObjectsFromArray:@[
			[view.leadingAnchor  constraintEqualToAnchor:view.superview.leadingAnchor],
			[view.topAnchor      constraintEqualToAnchor:view.superview.topAnchor    ],
			[view.widthAnchor    constraintEqualToConstant:NSWidth(view.frame)       ],
			[view.heightAnchor   constraintEqualToConstant:NSHeight(view.frame)      ],
		]];
	}

	if(_viewFrameConstraints)
		[NSLayoutConstraint deactivateConstraints:_viewFrameConstraints];
	_viewFrameConstraints = viewFrameConstraints;
	[NSLayoutConstraint activateConstraints:_viewFrameConstraints];

	NSUInteger animationCounter = ++_animationCounter;

	auto animationBody = ^(BOOL animated){
		_currentSubview.alphaValue = 0;
		_currentSubview = newView;
		newView.alphaValue = 1;
		if(animated)
				[window setFrame:newFrame display:YES animate:YES];
		else	[window setFrame:newFrame display:YES];
	};

	auto animationCompletion = ^{
		if(animationCounter == _animationCounter)
		{
			[NSLayoutConstraint deactivateConstraints:_viewFrameConstraints];
			_viewFrameConstraints = nil;

			for(NSView* view in _hostedSubviews)
			{
				if(view != newView)
					[view removeFromSuperview];
			}
			[_hostedSubviews removeAllObjects];

			if(newView)
			{
				[_hostedSubviews addObject:newView];

				_viewFrameConstraints = @[
					[newView.leadingAnchor  constraintEqualToAnchor:newView.superview.leadingAnchor ],
					[newView.bottomAnchor   constraintEqualToAnchor:newView.superview.bottomAnchor  ],
					[newView.topAnchor      constraintEqualToAnchor:newView.superview.topAnchor     ],
					[newView.trailingAnchor constraintEqualToAnchor:newView.superview.trailingAnchor],
				];
				[NSLayoutConstraint activateConstraints:_viewFrameConstraints];

				[window recalculateKeyViewLoop];
				if(window && window.firstResponder == window)
				{
					// selectKeyViewFollowingView: will select toolbar buttons when Full Keyboard Access is enabled

					std::set<NSView*> avoidLoops;
					for(NSView* keyView = newView; keyView && avoidLoops.find(keyView) == avoidLoops.end(); keyView = keyView.nextKeyView)
					{
						if(keyView.canBecomeKeyView)
						{
							[window makeFirstResponder:keyView];
							break;
						}
						avoidLoops.insert(keyView);
					}
				}
			}
			else
			{
				_viewFrameConstraints = @[
					[self.view.heightAnchor constraintEqualToConstant:0]
				];
				[NSLayoutConstraint activateConstraints:_viewFrameConstraints];
			}
		}
	};

	if(@available(macos 10.15, *))
	{
		if(window && window.isVisible)
		{
			[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
				context.allowsImplicitAnimation = YES;
				context.duration                = 0.2;
				animationBody(NO);
			} completionHandler:animationCompletion];
		}
		else
		{
			animationBody(NO);
			animationCompletion();
		}
	}
	else
	{
		animationBody(YES);
		animationCompletion();
	}
}
@end
