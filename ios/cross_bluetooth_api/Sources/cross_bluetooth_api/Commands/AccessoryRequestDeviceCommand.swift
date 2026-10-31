import AccessorySetupKit
import CoreBluetooth
import Flutter
import UIKit

@available(iOS 18.0, *)
@MainActor
final class AccessoryRequestDeviceCommand: BaseCommand, @unchecked Sendable {
    private var session: ASAccessorySession?
    private var displayItems: [ASPickerDisplayItem] = []
    private var selectedDevice: Device?
    private var completed = false
    private var sessionActivationStarted = false

    private struct InvalidOptions: Error {
        let message: String
    }

    init(
        arguments: [String: AnyObject]? = [:],
        session: ASAccessorySession? = nil,
        pendingResult: @escaping FlutterResult
    ) {
        self.session = session
        super.init(id: .requestDevice, arguments: arguments, pendingResult: pendingResult)
    }

    override func execute() async {
        switch makeDisplayItems() {
        case .success(let items):
            displayItems = items
        case .failure(let error):
            finish(FlutterError(
                code: "NotSupportedError",
                message: error.message,
                details: nil
            ))
            return
        }
        let session = session ?? ASAccessorySession()
        self.session = session
        sessionActivationStarted = true
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
            session?.showPicker(for: displayItems) { error in
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
        if sessionActivationStarted {
            sessionActivationStarted = false
            session?.invalidate()
        }
        pendingResult(result)
    }

    private func makeDisplayItems() -> Result<[ASPickerDisplayItem], InvalidOptions> {
        let options = RequestDeviceOptions.fromMap(arguments)
        guard !options.acceptAllDevices,
              let filters = options.filters, !filters.isEmpty else {
            return .failure(InvalidOptions(message: "Accessory setup requires discovery filters and does not support acceptAllDevices."))
        }

        var items: [ASPickerDisplayItem] = []

        for filter in filters {
            guard (filter.manufacturerData?.count ?? 0) <= 1,
                  (filter.services?.count ?? 0) <= 1 else {
                return .failure(InvalidOptions(message: "Accessory setup supports at most one service and manufacturer per filter."))
            }
            guard let productData = filter.productData else {
                return .failure(InvalidOptions(message: "Each accessory filter requires productData with a name and image asset."))
            }
            guard let productImage = UIImage(named: FlutterDartProject.lookupKey(forAsset: productData.image)) else {
                return .failure(InvalidOptions(message: "Accessory product image asset could not be loaded: \(productData.image)."))
            }
            let descriptor = ASDiscoveryDescriptor()
            if let service = filter.services?.first {
                descriptor.bluetoothServiceUUID = CBUUID(string: service)
            }
            if let manufacturerData = filter.manufacturerData?.first {
                guard let companyIdentifier = UInt16(exactly: manufacturerData.companyIdentifier) else {
                    return .failure(InvalidOptions(message: "Manufacturer companyIdentifier must be between 0 and 65535."))
                }
                descriptor.bluetoothCompanyIdentifier = ASBluetoothCompanyIdentifier(rawValue: companyIdentifier)

                let prefix = manufacturerData.dataPrefix ?? []
                let prefixBytes = prefix.compactMap(UInt8.init(exactly:))
                guard prefixBytes.count == prefix.count else {
                    return .failure(InvalidOptions(message: "Manufacturer dataPrefix values must be between 0 and 255."))
                }
                if !prefixBytes.isEmpty {
                    descriptor.bluetoothManufacturerDataBlob = Data(prefixBytes)
                }

                if let mask = manufacturerData.mask {
                    let maskBytes = mask.compactMap(UInt8.init(exactly:))
                    guard maskBytes.count == mask.count else {
                        return .failure(InvalidOptions(message: "Manufacturer mask values must be between 0 and 255."))
                    }
                    guard maskBytes.count == prefixBytes.count else {
                        return .failure(InvalidOptions(message: "Manufacturer mask must have the same length as dataPrefix."))
                    }
                    if !maskBytes.isEmpty {
                        descriptor.bluetoothManufacturerDataMask = Data(maskBytes)
                    }
                }
            }
            if let prefix = filter.namePrefix {
                guard !prefix.isEmpty else {
                    return .failure(InvalidOptions(message: "Accessory namePrefix must not be empty."))
                }
                if #available(iOS 18.2, *) {
                    descriptor.bluetoothNameSubstring = prefix
                    descriptor.bluetoothNameSubstringCompareOptions = [.anchored, .literal]
                } else {
                    return .failure(InvalidOptions(message: "Accessory namePrefix requires iOS 18.2 or newer."))
                }
            }
            guard descriptor.bluetoothServiceUUID != nil
                || descriptor.bluetoothNameSubstring != nil
                || !(filter.manufacturerData?.isEmpty ?? true) else {
                return .failure(InvalidOptions(message: "Accessory setup requires a service, name prefix, or manufacturer filter."))
            }
            items.append(ASPickerDisplayItem(
                name: productData.name,
                productImage: productImage,
                descriptor: descriptor
            ))
        }
        return .success(items)
    }
}
