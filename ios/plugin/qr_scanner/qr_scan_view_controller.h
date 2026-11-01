// The full screen camera view of the iPhone scanner (REQ-FL-88). Plain UIKit and AVFoundation.
#import <UIKit/UIKit.h>

// Called once, on the main thread, after the view is gone. `text` is the QR text, or nil with `reason` set
// (cancelled, error).
typedef void (^QrScanDone)(NSString *_Nullable text, NSString *_Nullable reason);

@interface QrScanViewController : UIViewController

- (instancetype _Nonnull)initWithHint:(NSString *_Nonnull)hint cancel:(NSString *_Nonnull)cancel done:(QrScanDone _Nonnull)done;

@end
