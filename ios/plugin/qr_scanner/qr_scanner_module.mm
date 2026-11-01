// STATUS: written on Linux, never built, never run. The two functions named in QrScanner.gdip.
#import "qr_scanner.h"

#include "core/config/engine.h"

static QrScanner *plugin = nullptr;

void qr_scanner_init() {
	// Without the registration _bind_methods() never runs and GDScript cannot call scan() or connect the signals.
	GDREGISTER_CLASS(QrScanner);
	plugin = memnew(QrScanner);
	Engine::get_singleton()->add_singleton(Engine::Singleton("QrScanner", plugin));
}

void qr_scanner_deinit() {
	if (plugin) {
		memdelete(plugin);
		plugin = nullptr;
	}
}
