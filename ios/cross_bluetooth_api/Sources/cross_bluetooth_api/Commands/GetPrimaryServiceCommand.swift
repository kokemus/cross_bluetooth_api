import Foundation
import Flutter
import CoreBluetooth

public class GetPrimaryServiceCommand: BaseCommand, CBPeripheralDelegate {
    private let manager: BluetoothManager
    private var continuation: CheckedContinuation<Void, Never>?
    private var targetDeviceId: String?
    private var targetServiceUUID: CBUUID?

    init(
        manager: BluetoothManager,
        arguments: [String: AnyObject]?,
        pendingResult: @escaping FlutterResult
    ) {
        self.manager = manager
        super.init(id: .getPrimaryService, arguments: arguments, pendingResult: pendingResult)
    }

    override func execute() async {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            guard let deviceId = arguments["deviceId"] as? String,
                  let serviceUUIDString = arguments["serviceUUID"] as? String,
                  let peripheral = manager.peripheral(for: deviceId) else {
                pendingResult(getPrimaryServiceNetworkError)
                continuation.resume()
                return
            }

            targetDeviceId = deviceId
            targetServiceUUID = CBUUID(string: serviceUUIDString)
            peripheral.delegate = self
            peripheral.discoverServices([targetServiceUUID!])
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        defer {
            continuation?.resume()
        }

        if error != nil {
            pendingResult(getPrimaryServiceNotFoundError)
            return
        }

        guard
            peripheral.identifier.uuidString == targetDeviceId,
            let serviceUUID = targetServiceUUID,
            let service = peripheral.services?.first(where: { $0.uuid == serviceUUID })
        else {
            pendingResult(getPrimaryServiceNotFoundError)
            return
        }

        pendingResult(service.toMap())
    }
}

private let getPrimaryServiceNetworkError = FlutterError(
    code: "NetworkError",
    message: "NetworkError: A network error occurred.",
    details: nil
)

private let getPrimaryServiceNotFoundError = FlutterError(
    code: "NotFoundError",
    message: "NotFoundError: There is no Bluetooth device that matches the specified options.",
    details: nil
)
