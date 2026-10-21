package io.github.alonzo86.sababi;

import android.app.Activity;
import android.content.Context;
import android.net.wifi.WifiManager;
import android.os.Build;

import androidx.annotation.NonNull;

import com.google.mlkit.common.MlKitException;
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
 * It also holds the Wi-Fi locks that the controller needs (low-latency mode, multicast).
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
							// The Back key in the scanner is reported as a failure ("Failed to scan code"), not as a cancel.
							if (e instanceof MlKitException
									&& ((MlKitException) e).getErrorCode() == MlKitException.CODE_SCANNER_CANCELLED) {
								emitSignal(SIGNAL_FAILED, "cancelled");
								return;
							}
							String message = e.getMessage();
							emitSignal(SIGNAL_FAILED, message == null ? "error" : message);
						});
			} catch (RuntimeException e) {
				scanning = false;
				emitSignal(SIGNAL_FAILED, String.valueOf(e.getMessage()));
			}
		});
	}

	private WifiManager.WifiLock wifiLock;
	private WifiManager.MulticastLock multicastLock;

	/**
	 * Hold the Wi-Fi radio in low-latency mode (no power save bursts) and accept broadcast packets
	 * (the TV beacon). Call it when the controller starts. It is safe to call again.
	 */
	@UsedByGodot
	public void acquireWifiLocks() {
		final Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		try {
			WifiManager wifi = (WifiManager) activity.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
			if (wifi == null) {
				return;
			}
			if (wifiLock == null) {
				int mode = Build.VERSION.SDK_INT >= 29
						? WifiManager.WIFI_MODE_FULL_LOW_LATENCY
						: WifiManager.WIFI_MODE_FULL_HIGH_PERF;
				wifiLock = wifi.createWifiLock(mode, "sababi:latency");
				wifiLock.setReferenceCounted(false);
			}
			if (!wifiLock.isHeld()) {
				wifiLock.acquire();
			}
			if (multicastLock == null) {
				multicastLock = wifi.createMulticastLock("sababi:beacon");
				multicastLock.setReferenceCounted(false);
			}
			if (!multicastLock.isHeld()) {
				multicastLock.acquire();
			}
		} catch (RuntimeException e) {
			// Missing permission or no Wi-Fi. The app still works without the locks.
		}
	}

	@UsedByGodot
	public void releaseWifiLocks() {
		if (wifiLock != null && wifiLock.isHeld()) {
			wifiLock.release();
		}
		if (multicastLock != null && multicastLock.isHeld()) {
			multicastLock.release();
		}
	}

	@Override
	public void onMainDestroy() {
		releaseWifiLocks();
	}
}
