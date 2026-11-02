import AccessorySetupKit
import Flutter

@available(iOS 18.0, *)
final class AccessoryForgetCommand: BaseCommand {
    private let session: ASAccessorySession
    private var completed = false
    private var removalStarted = false

    init(
        arguments: [String: AnyObject]?,
        session: ASAccessorySession = ASAccessorySession(),
        pendingResult: @escaping FlutterResult
    ) {
        self.session = session
        super.init(id: .forget, arguments: arguments, pendingResult: pendingResult)
    }

    override func execute() async {
        guard let deviceId = arguments["id"] as? String, UUID(uuidString: deviceId) != nil else {
            finish(FlutterError.notFoundError())
            return
        }
        session.activate(on: .main, eventHandler: handle(event:))
    }

    func handle(event: ASAccessoryEvent) {
        handle(event.eventType, error: event.error)
    }

    func handle(_ eventType: ASAccessoryEventType, error: Error? = nil) {
        guard !completed else { return }
        if let error {
            finishError(error)
            return
        }
        switch eventType {
        case .activated:
            guard !removalStarted else { return }
            removalStarted = true
            guard let deviceId = arguments["id"] as? String else {
                finish(FlutterError.notFoundError())
                return
            }
            guard let accessory = session.accessories.first(where: {
                $0.bluetoothIdentifier == UUID(uuidString: deviceId)
            }) else {
                finish(FlutterError.notSupportedError(
                    message: "The device is not an AccessorySetupKit accessory."
                ))
                return
            }
            session.removeAccessory(accessory) { error in
                guard !self.completed else { return }
                if let error {
                    self.finishError(error)
                } else {
                    self.finish(nil)
                }
            }
        case .invalidated:
            finish(FlutterError.networkError())
        default:
            break
        }
    }

    private func finishError(_ error: Error) {
        let error = error as NSError
        finish(FlutterError.networkError(
            message: error.localizedDescription,
            details: ["domain": error.domain, "code": error.code]
        ))
    }

    private func finish(_ result: Any?) {
        guard !completed else { return }
        completed = true
        session.invalidate()
        complete(result)
    }
}
