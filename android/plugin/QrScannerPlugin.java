package com.example.remoteplay;

import android.app.Activity;

import androidx.annotation.NonNull;

import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions;
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

/**
 * Godot Android plugin "QrScanner". It opens the Google code scanner (ML Kit, Google Play services).
 * That scanner has its own screen and needs no camera permission in this app.
 *
 * GDScript use:
 *   var qr = Engine.get_singleton("QrScanner")
 *   qr.scanned.connect(func(text): ...)
 *   qr.failed.connect(func(reason): ...)   # "cancelled" or an error text
 *   qr.scan()
 */
public class QrScannerPlugin extends GodotPlugin {
	private static final String SIGNAL_SCANNED = "scanned";
	private static final String SIGNAL_FAILED = "failed";

	private boolean scanning = false;

	public QrScannerPlugin(Godot godot) {
		super(godot);
	}

	@NonNull
	@Override
	public String getPluginName() {
		return "QrScanner";
	}

	@NonNull
	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(new SignalInfo(SIGNAL_SCANNED, String.class));
		signals.add(new SignalInfo(SIGNAL_FAILED, String.class));
		return signals;
	}

	/** Start a scan. The result comes back as the signal "scanned" or "failed". */
	@UsedByGodot
	public void scan() {
		final Activity activity = getActivity();
		if (activity == null) {
			emitSignal(SIGNAL_FAILED, "no_activity");
			return;
		}
		if (scanning) {
			return;
		}
		scanning = true;
		runOnUiThread(() -> {
			try {
				GmsBarcodeScannerOptions options = new GmsBarcodeScannerOptions.Builder()
						.setBarcodeFormats(Barcode.FORMAT_QR_CODE)
						.build();
				GmsBarcodeScanning.getClient(activity, options)
						.startScan()
						.addOnSuccessListener(barcode -> {
							scanning = false;
							String value = barcode.getRawValue();
							emitSignal(SIGNAL_SCANNED, value == null ? "" : value);
						})
						.addOnCanceledListener(() -> {
							scanning = false;
							emitSignal(SIGNAL_FAILED, "cancelled");
						})
						.addOnFailureListener(e -> {
							scanning = false;
							String message = e.getMessage();
							emitSignal(SIGNAL_FAILED, message == null ? "error" : message);
						});
			} catch (RuntimeException e) {
				scanning = false;
				emitSignal(SIGNAL_FAILED, String.valueOf(e.getMessage()));
			}
		});
	}
}
