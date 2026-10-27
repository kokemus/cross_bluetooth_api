import AccessorySetupKit
import Flutter

@available(iOS 18.0, *)
@MainActor
final class AccessoryGetDevicesCommand: BaseCommand, @unchecked Sendable {
    private let session: ASAccessorySession
    private var completed = false

    init(
        session: ASAccessorySession = ASAccessorySession(),
        pendingResult: @escaping FlutterResult
    ) {
        self.session = session
        super.init(id: .getDevices, arguments: nil, pendingResult: pendingResult)
    }

    override func execute() async {
        session.activate(on: .main) { event in
            MainActor.assumeIsolated {
                self.handle(event.eventType, error: event.error)
            }
        }
    }

    func handle(_ eventType: ASAccessoryEventType, error: Error? = nil) {
        guard !completed else { return }
        if let error {
            let error = error as NSError
            finish(FlutterError(
                code: "UnknownError",
                message: error.localizedDescription,
                details: ["domain": error.domain, "code": error.code]
            ))
            return
        }
        switch eventType {
        case .activated:
            let devices = session.accessories.compactMap { accessory -> Device? in
                guard accessory.state == .authorized,
                      let identifier = accessory.bluetoothIdentifier else {
                    return nil
                }
                return Device(id: identifier.uuidString, name: accessory.displayName)
            }
            finish(devices.map { $0.toMap() })
        case .invalidated:
            finish(FlutterError.networkError())
        default:
            break
        }
    }

    private func finish(_ result: Any) {
        guard !completed else { return }
        completed = true
        session.invalidate()
        complete(result)
    }
}
