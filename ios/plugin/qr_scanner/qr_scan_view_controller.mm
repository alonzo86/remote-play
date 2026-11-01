// STATUS: written on Linux, never built, never run. Read the life cycle with care (code-reviewer):
// the capture session starts in viewDidAppear and stops on every way out; the delegate is cleared before
// the session stops; `done` runs once (the `finished` flag).
#import "qr_scan_view_controller.h"

#import <AVFoundation/AVFoundation.h>

static const CGFloat kCancelHeight = 96.0; // points; REQ-FL-88 asks for 96 or more
static const CGFloat kMargin = 16.0;

@interface QrScanViewController () <AVCaptureMetadataOutputObjectsDelegate>
@end

@implementation QrScanViewController {
	NSString *_hint;
	NSString *_cancel;
	QrScanDone _done;
	AVCaptureSession *_session;
	AVCaptureMetadataOutput *_output;
	AVCaptureVideoPreviewLayer *_preview;
	dispatch_queue_t _sessionQueue; // startRunning and stopRunning block, so they never run on the main thread
	UILabel *_hintLabel;
	UIButton *_cancelButton;
	BOOL _finished;
}

- (instancetype)initWithHint:(NSString *)hint cancel:(NSString *)cancel done:(QrScanDone)done {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
		_hint = [hint copy];
		_cancel = [cancel copy];
		_done = [done copy];
		_sessionQueue = dispatch_queue_create("sababi.qrscanner.session", DISPATCH_QUEUE_SERIAL);
		self.modalPresentationStyle = UIModalPresentationFullScreen;
	}
	return self;
}

#pragma mark - Orientation: portrait only, like the app

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
	return NO;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
	return UIInterfaceOrientationPortrait;
}

#pragma mark - View

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = UIColor.blackColor;

	_session = [[AVCaptureSession alloc] init];
	AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	NSError *error = nil;
	AVCaptureDeviceInput *input = device ? [AVCaptureDeviceInput deviceInputWithDevice:device error:&error] : nil;
	_output = [[AVCaptureMetadataOutput alloc] init];
	if (input && [_session canAddInput:input] && [_session canAddOutput:_output]) {
		[_session addInput:input];
		[_session addOutput:_output];
		// The types must be set after the output is on the session. Only QR codes are read (REQ-FL-89).
		if ([_output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]) {
			_output.metadataObjectTypes = @[ AVMetadataObjectTypeQRCode ];
			[_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
		} else {
			_session = nil;
		}
	} else {
		_session = nil;
	}

	if (_session) {
		_preview = [AVCaptureVideoPreviewLayer layerWithSession:_session];
		_preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
		[self.view.layer addSublayer:_preview];
	}

	_hintLabel = [[UILabel alloc] init];
	_hintLabel.text = _hint;
	_hintLabel.textColor = UIColor.whiteColor;
	_hintLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
	_hintLabel.font = [UIFont boldSystemFontOfSize:20];
	_hintLabel.textAlignment = NSTextAlignmentCenter; // centered, so Hebrew needs no mirror
	_hintLabel.numberOfLines = 0;
	_hintLabel.layer.masksToBounds = YES;
	_hintLabel.layer.cornerRadius = 8;
	[self.view addSubview:_hintLabel];

	_cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
	[_cancelButton setTitle:_cancel forState:UIControlStateNormal];
	_cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:28];
	[_cancelButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
	_cancelButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
	[_cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:_cancelButton];

	// A swipe down closes the view like CANCEL (REQ-FL-90).
	UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(cancelTapped)];
	swipe.direction = UISwipeGestureRecognizerDirectionDown;
	[self.view addGestureRecognizer:swipe];

	// The app goes to the background, or a phone call comes: close the view (REQ-FL-88, 90).
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(cancelTapped)
												 name:UIApplicationWillResignActiveNotification
											   object:nil];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGRect bounds = self.view.bounds;
	UIEdgeInsets safe = self.view.safeAreaInsets;
	_preview.frame = bounds;
	if (_preview.connection.isVideoOrientationSupported) {
		_preview.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
	}

	CGFloat width = bounds.size.width - 2 * kMargin;
	CGSize fit = [_hintLabel sizeThatFits:CGSizeMake(width - 2 * kMargin, CGFLOAT_MAX)];
	_hintLabel.frame = CGRectMake(kMargin, safe.top + kMargin, width, fit.height + 2 * kMargin);

	CGFloat buttonHeight = kCancelHeight + safe.bottom;
	_cancelButton.frame = CGRectMake(0, bounds.size.height - buttonHeight, bounds.size.width, buttonHeight);
	_cancelButton.contentEdgeInsets = UIEdgeInsetsMake(0, 0, safe.bottom, 0);
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (!_session) {
		[self finishWithText:nil reason:@"error"];
		return;
	}
	AVCaptureSession *session = _session;
	dispatch_async(_sessionQueue, ^{
		[session startRunning];
	});
}

#pragma mark - Results

- (void)cancelTapped {
	[self finishWithText:nil reason:@"cancelled"];
}

- (void)captureOutput:(AVCaptureOutput *)output
	didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects
			  fromConnection:(AVCaptureConnection *)connection {
	for (AVMetadataObject *object in metadataObjects) {
		if ([object isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
			NSString *value = ((AVMetadataMachineReadableCodeObject *)object).stringValue;
			if (value.length > 0) {
				[self finishWithText:value reason:nil]; // the first QR code seen (REQ-FL-89)
				return;
			}
		}
	}
}

// Stops the camera, removes the view, then calls `done` once. Main thread only.
- (void)finishWithText:(NSString *)text reason:(NSString *)reason {
	if (_finished) {
		return;
	}
	_finished = YES;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_output setMetadataObjectsDelegate:nil queue:nil]; // no more callbacks into this object
	AVCaptureSession *session = _session;
	_session = nil;
	if (session) {
		dispatch_async(_sessionQueue, ^{
			[session stopRunning]; // the camera is off after this (REQ-FL-88)
		});
	}
	QrScanDone done = _done;
	_done = nil; // break the reference to the plugin
	[self dismissViewControllerAnimated:NO
							 completion:^{
								 if (done) {
									 done(text, reason);
								 }
							 }];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
