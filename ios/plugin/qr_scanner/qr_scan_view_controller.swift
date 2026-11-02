// The full screen camera view of the iPhone scanner (REQ-FL-88). Swift, because Apple's VisionKit
// DataScannerViewController has no Objective-C interface. qr_scan_view_controller.h declares this class for
// qr_scanner.mm; the @objc name below is the link between the two.
// STATUS: compiled with swiftc only (tools/build_ios_plugin.sh), never run on a device. Read the life cycle with care
// (code-reviewer): scanning starts in viewDidAppear and stops on every way out; `done` runs once (`finished`).
import UIKit
import VisionKit

private let cancelHeight: CGFloat = 96 // points; REQ-FL-88 asks for 96 or more
private let margin: CGFloat = 16

@objc(QrScanViewController)
public final class QrScanViewController: UIViewController, DataScannerViewControllerDelegate {
	private let hint: String
	private let cancelTitle: String
	private var done: ((String?, String?) -> Void)?
	private var scanner: DataScannerViewController?
	private let hintLabel = UILabel()
	private let cancelButton = UIButton(type: .system)
	private var finished = false

	/// True when this phone can run the VisionKit scanner (an A12 chip or newer, REQ-FL-58). Asked by the plugin
	/// before it shows the SCAN QR CODE button.
	@objc public class func isScannerSupported() -> Bool {
		return DataScannerViewController.isSupported
	}

	@objc public init(hint: String, cancel: String, done: @escaping (String?, String?) -> Void) {
		self.hint = hint
		self.cancelTitle = cancel
		self.done = done
		super.init(nibName: nil, bundle: nil)
		modalPresentationStyle = .fullScreen
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not used")
	}

	// MARK: Orientation: portrait only, like the app

	public override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
	public override var shouldAutorotate: Bool { false }
	public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }

	// MARK: View

	public override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .black

		// Only QR codes are read (REQ-FL-89); the first one seen ends the scan.
		let scanner = DataScannerViewController(
			recognizedDataTypes: [.barcode(symbologies: [.qr])],
			qualityLevel: .balanced,
			recognizesMultipleItems: false,
			isHighFrameRateTrackingEnabled: false,
			isPinchToZoomEnabled: true,
			isGuidanceEnabled: false,
			isHighlightingEnabled: true)
		scanner.delegate = self
		addChild(scanner)
		view.addSubview(scanner.view)
		scanner.didMove(toParent: self)
		self.scanner = scanner

		hintLabel.text = hint
		hintLabel.textColor = .white
		hintLabel.backgroundColor = UIColor(white: 0, alpha: 0.6)
		hintLabel.font = .boldSystemFont(ofSize: 20)
		hintLabel.textAlignment = .center // centered, so Hebrew needs no mirror
		hintLabel.numberOfLines = 0
		hintLabel.layer.masksToBounds = true
		hintLabel.layer.cornerRadius = 8
		view.addSubview(hintLabel)

		applyCancelStyle(bottomInset: 0)
		cancelButton.backgroundColor = UIColor(white: 0, alpha: 0.7)
		cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
		view.addSubview(cancelButton)

		// A swipe down closes the view like CANCEL (REQ-FL-90).
		let swipe = UISwipeGestureRecognizer(target: self, action: #selector(cancelTapped))
		swipe.direction = .down
		view.addGestureRecognizer(swipe)

		// The app goes to the background, or a phone call comes: close the view (REQ-FL-88, 90).
		NotificationCenter.default.addObserver(
			self, selector: #selector(cancelTapped), name: UIApplication.willResignActiveNotification, object: nil)
	}

	public override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		let bounds = view.bounds
		let safe = view.safeAreaInsets
		scanner?.view.frame = bounds

		let width = bounds.width - 2 * margin
		let fit = hintLabel.sizeThatFits(CGSize(width: width - 2 * margin, height: .greatestFiniteMagnitude))
		hintLabel.frame = CGRect(x: margin, y: safe.top + margin, width: width, height: fit.height + 2 * margin)

		let buttonHeight = cancelHeight + safe.bottom
		cancelButton.frame = CGRect(x: 0, y: bounds.height - buttonHeight, width: bounds.width, height: buttonHeight)
		applyCancelStyle(bottomInset: safe.bottom) // the title stays above the home indicator
	}

	private func applyCancelStyle(bottomInset: CGFloat) {
		var configuration = UIButton.Configuration.plain()
		configuration.attributedTitle = AttributedString(
			cancelTitle,
			attributes: AttributeContainer([.font: UIFont.boldSystemFont(ofSize: 28), .foregroundColor: UIColor.white]))
		configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: bottomInset, trailing: 0)
		cancelButton.configuration = configuration
	}

	public override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		guard let scanner = scanner, DataScannerViewController.isAvailable else {
			finish(text: nil, reason: "error") // for example a parental restriction
			return
		}
		do {
			try scanner.startScanning()
		} catch {
			finish(text: nil, reason: "error")
		}
	}

	// MARK: Results

	@objc private func cancelTapped() {
		finish(text: nil, reason: "cancelled")
	}

	public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
							allItems: [RecognizedItem]) {
		for item in addedItems {
			if case .barcode(let code) = item, let value = code.payloadStringValue, !value.isEmpty {
				finish(text: value, reason: nil) // the first QR code seen (REQ-FL-89)
				return
			}
		}
	}

	public func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
		// The camera was taken away after the start (for example by the system): report it as a plain error.
		finish(text: nil, reason: "error")
	}

	/// Stops the camera, removes the view, then calls `done` once. Main thread only.
	private func finish(text: String?, reason: String?) {
		if finished {
			return
		}
		finished = true
		NotificationCenter.default.removeObserver(self)
		scanner?.delegate = nil // no more callbacks into this object
		scanner?.stopScanning() // the camera is off after this (REQ-FL-88)
		let callback = done
		done = nil // break the reference to the plugin
		dismiss(animated: false) {
			callback?(text, reason)
		}
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}
