// The full screen camera view of the iPhone scanner (REQ-FL-88). The class is written in Swift
// (qr_scan_view_controller.swift, @objc name QrScanViewController) because Apple's VisionKit scanner has no
// Objective-C interface. This header only tells qr_scanner.mm what the Swift class offers.
#import <UIKit/UIKit.h>

// Called once, on the main thread, after the view is gone. `text` is the QR text, or nil with `reason` set
// (cancelled, error).
typedef void (^QrScanDone)(NSString *_Nullable text, NSString *_Nullable reason);

@interface QrScanViewController : UIViewController

// YES on a phone with an A12 chip or newer (VisionKit's DataScannerViewController.isSupported).
+ (BOOL)isScannerSupported;

- (instancetype _Nonnull)initWithHint:(NSString *_Nonnull)hint cancel:(NSString *_Nonnull)cancel done:(QrScanDone _Nonnull)done;

@end
