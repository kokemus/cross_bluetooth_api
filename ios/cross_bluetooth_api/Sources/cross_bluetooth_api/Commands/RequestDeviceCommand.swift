import Foundation
import Flutter
import UIKit
import CoreBluetooth

public class RequestDeviceCommand: BaseCommand, RequestDeviceDelegate {
    let viewController: UIViewController
    
    init(
        viewController: UIViewController,
        arguments: [String: AnyObject]? = [:],
        pendingResult: @escaping FlutterResult,
        eventSink: FlutterEventSink? = nil
    ) {
        self.viewController = viewController
        super.init(id: .requestDevice, arguments: arguments, pendingResult: pendingResult)
    }

    override func execute() async {
        await viewController.present(
            RequestDeviceViewController(options: arguments, delegate: self),
            animated: true,
            completion: nil
        )
    }

    func requestDevice(_ requestDevice: RequestDeviceViewController, didRequest peripheral: CBPeripheral) {
        viewController.dismiss(animated: true, completion: nil)
        pendingResult(Device.fromPeripheral(peripheral).toMap())
    }

    func requestDevice(_ requestDevice: RequestDeviceViewController, didFailWithError error: RequestDeviceError) {
        viewController.dismiss(animated: true, completion: nil)
        switch (error) {
        case .userCancelled:
            pendingResult(FlutterError.userCancelledError())
        default:
            pendingResult(FlutterError.notFoundError())
        }
    }
}
