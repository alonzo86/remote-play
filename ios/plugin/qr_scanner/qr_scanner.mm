// STATUS: written on Linux, never built, never run. See qr_scanner.h.
#import "qr_scanner.h"

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "qr_scan_view_controller.h"

QrScanner *QrScanner::instance = nullptr;

static NSString *to_ns(const String &p_string) {
	return [NSString stringWithUTF8String:p_string.utf8().get_data()];
}

static String from_ns(NSString *p_string) {
	return p_string ? String::utf8([p_string UTF8String]) : String();
}

// The view controller that is on top of the Godot view now.
static UIViewController *top_view_controller() {
	UIWindow *window = nil;
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
			for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
				if (candidate.isKeyWindow) {
					window = candidate;
				}
			}
		}
	}
	UIViewController *top = window.rootViewController;
	while (top.presentedViewController) {
		top = top.presentedViewController;
	}
	return top;
}

void QrScanner::_bind_methods() {
	ClassDB::bind_method(D_METHOD("scan", "hint", "cancel"), &QrScanner::scan);
	ADD_SIGNAL(MethodInfo("scanned", PropertyInfo(Variant::STRING, "text")));
	ADD_SIGNAL(MethodInfo("failed", PropertyInfo(Variant::STRING, "reason")));
}

QrScanner *QrScanner::get_singleton() {
	return instance;
}

QrScanner::QrScanner() {
	instance = this;
}

QrScanner::~QrScanner() {
	instance = nullptr;
	if (view_controller) {
		CFRelease(view_controller);
		view_controller = nullptr;
	}
}

void QrScanner::scan(const String &p_hint, const String &p_cancel) {
	if (view_controller) {
		return; // a view is open already
	}
	// Godot calls this on the main thread, but the permission answer comes on another one: the copy of the texts
	// goes into the blocks as NSString, not as a reference to a Godot String.
	NSString *hint = to_ns(p_hint);
	NSString *cancel = to_ns(p_cancel);

	if ([AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] == nil) {
		finish(String(), "no_camera"); // the simulator, or a device with no camera (REQ-FL-91)
		return;
	}

	switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
		case AVAuthorizationStatusAuthorized:
			present_view(from_ns(hint), from_ns(cancel));
			break;
		case AVAuthorizationStatusNotDetermined:
			// iOS shows the question with NSCameraUsageDescription, once (REQ-FL-91).
			[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
									 completionHandler:^(BOOL granted) {
										 dispatch_async(dispatch_get_main_queue(), ^{
											 if (granted) {
												 present_view(from_ns(hint), from_ns(cancel));
											 } else {
												 finish(String(), "camera_denied");
											 }
										 });
									 }];
			break;
		case AVAuthorizationStatusDenied:
		case AVAuthorizationStatusRestricted:
		default:
			finish(String(), "camera_denied");
			break;
	}
}

void QrScanner::present_view(const String &p_hint, const String &p_cancel) {
	if (view_controller) {
		return;
	}
	UIViewController *top = top_view_controller();
	if (!top) {
		finish(String(), "error");
		return;
	}
	QrScanViewController *controller = [[QrScanViewController alloc] initWithHint:to_ns(p_hint)
																			cancel:to_ns(p_cancel)
																			  done:^(NSString *text, NSString *reason) {
																				  QrScanner *scanner = QrScanner::get_singleton();
																				  if (scanner) {
																					  scanner->finish(from_ns(text), from_ns(reason));
																				  }
																			  }];
	view_controller = (void *)CFBridgingRetain(controller);
	[top presentViewController:controller animated:NO completion:nil];
}

void QrScanner::finish(const String &p_text, const String &p_reason) {
	if (view_controller) {
		CFRelease(view_controller);
		view_controller = nullptr;
	}
	if (!p_text.is_empty()) {
		emit_signal("scanned", p_text);
	} else {
		emit_signal("failed", p_reason.is_empty() ? String("error") : p_reason);
	}
}
