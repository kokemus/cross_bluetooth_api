import AccessorySetupKit
import CoreBluetooth
import Flutter
import UIKit

@available(iOS 18.0, *)
@MainActor
final class AccessoryRequestDeviceCommand: BaseCommand, @unchecked Sendable {
    private let session: ASAccessorySession
    private var displayItems: [ASPickerDisplayItem] = []
    private var selectedDevice: Device?
    private var completed = false

    init(
        arguments: [String: AnyObject]? = [:],
        session: ASAccessorySession = ASAccessorySession(),
        pendingResult: @escaping FlutterResult
    ) {
        self.session = session
        super.init(id: .requestDevice, arguments: arguments, pendingResult: pendingResult)
    }

    override func execute() async {
        guard let items = makeDisplayItems() else {
            finish(FlutterError(
                code: "NotSupportedError",
                message: "The request options cannot be represented by AccessorySetupKit discovery descriptors.",
                details: nil
            ))
            return
        }
        displayItems = items
        session.activate(on: .main) { event in
            MainActor.assumeIsolated {
                self.handle(event.eventType, accessory: event.accessory, error: event.error)
            }
        }
    }

    func handle(_ eventType: ASAccessoryEventType, accessory: ASAccessory? = nil, error: Error? = nil) {
        guard !completed else { return }
        if let error {
            finish(error: error)
            return
        }

        switch eventType {
        case .activated:
            session.showPicker(for: displayItems) { error in
                if let error {
                    DispatchQueue.main.async {
                        self.finish(error: error)
                    }
                }
            }
        case .accessoryAdded, .accessoryChanged:
            if let accessory,
               accessory.state == .authorized,
               let identifier = accessory.bluetoothIdentifier {
                selectedDevice = Device(id: identifier.uuidString, name: accessory.displayName)
            }
        case .pickerDidDismiss:
            finish(selectedDevice?.toMap() ?? FlutterError.userCancelledError())
        case .invalidated, .pickerSetupFailed:
            finish(FlutterError.notFoundError())
        default:
            break
        }
    }

    private func finish(error: Error) {
        let error = error as NSError
        if error.domain == ASErrorDomain, error.code == ASError.Code.userCancelled.rawValue {
            finish(FlutterError.userCancelledError())
            return
        }

        let connectionFailed = error.domain == ASErrorDomain
            && error.code == ASError.Code.connectionFailed.rawValue
        var details: [String: Any] = ["domain": error.domain, "code": error.code]
        if let reason = error.localizedFailureReason {
            details["failureReason"] = reason
        }
        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            details["underlyingError"] = [
                "domain": underlyingError.domain,
                "code": underlyingError.code,
                "message": underlyingError.localizedDescription
            ]
        }
        finish(FlutterError(
            code: connectionFailed ? "NetworkError" : "NotFoundError",
            message: connectionFailed
                ? "NetworkError: AccessorySetupKit could not connect to the selected accessory. \(error.localizedDescription)"
                : error.localizedDescription,
            details: details
        ))
    }

    private func finish(_ result: Any) {
        guard !completed else { return }
        completed = true
        session.invalidate()
        pendingResult(result)
    }

    private func makeDisplayItems() -> [ASPickerDisplayItem]? {
        let options = RequestDeviceOptions.fromMap(arguments)
        guard !options.acceptAllDevices,
              let filters = options.filters, !filters.isEmpty,
              let image = UIImage(systemName: "sensor.tag.radiowaves.forward") else {
            return nil
        }

        var items: [ASPickerDisplayItem] = []

        for filter in filters {
            guard (filter.services?.count ?? 0) <= 1 else { return nil }
            let descriptor = ASDiscoveryDescriptor()
            if let service = filter.services?.first {
                descriptor.bluetoothServiceUUID = CBUUID(string: service)
            }
            if let prefix = filter.namePrefix {
                guard !prefix.isEmpty else { return nil }
                if #available(iOS 18.2, *) {
                    descriptor.bluetoothNameSubstring = prefix
                    descriptor.bluetoothNameSubstringCompareOptions = [.anchored, .literal]
                } else {
                    return nil
                }
            }
            guard descriptor.bluetoothServiceUUID != nil || descriptor.bluetoothNameSubstring != nil else {
                return nil
            }
            let productImage = filter.productData.flatMap {
                UIImage(named: FlutterDartProject.lookupKey(forAsset: $0.image))
            } ?? image
            items.append(ASPickerDisplayItem(
                name: filter.productData?.name ?? filter.name ?? "Bluetooth Device",
                productImage: productImage,
                descriptor: descriptor
            ))
        }
        return items
    }
}
