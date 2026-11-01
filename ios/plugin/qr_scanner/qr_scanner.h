// QrScanner: Godot iOS plugin (own code on Apple AVFoundation, issue #299, REQ-FL-88 to 92).
// STATUS: written on Linux, never built, never run (no Xcode, no iPhone). Manual test 33 is the check.
//
// It registers the engine singleton "QrScanner" with the same name and signals as the Android plugin
// (android/plugin/QrScannerPlugin.java), so scripts/net/qr_scanner.gd is the one entry point:
//   scan(hint: String, cancel: String)  opens the camera view. The two texts come from GDScript (Lang),
//                                       the native code has no text of its own (REQ-FL-63).
//   signal scanned(text: String)        the text of the first QR code seen.
//   signal failed(reason: String)       one of: cancelled, camera_denied, no_camera, error.
#pragma once

#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/string/ustring.h"

class QrScanner : public Object {
	GDCLASS(QrScanner, Object);

	static QrScanner *instance;

	// The QrScanViewController that is on the screen now, or nullptr. Held with CFBridgingRetain,
	// released in finish(). Only the main thread touches it.
	void *view_controller = nullptr;

	void present_view(const String &p_hint, const String &p_cancel);

protected:
	static void _bind_methods();

public:
	static QrScanner *get_singleton();

	// Called from GDScript. Starts a scan; ignored while a scan view is open.
	void scan(const String &p_hint, const String &p_cancel);

	// Called by the view controller (main thread) when the view is done. Exactly one of the two is not empty.
	void finish(const String &p_text, const String &p_reason);

	QrScanner();
	~QrScanner();
};
