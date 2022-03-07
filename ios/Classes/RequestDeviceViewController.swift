import Foundation
import UIKit
import CoreBluetooth

protocol RequestDeviceDelegate {
    func requestDevice(_ requestDevice: RequestDeviceViewController, didRequest peripheral: CBPeripheral)
    func requestDevice(_ requestDevice: RequestDeviceViewController, didFailWithError error: RequestDeviceError)
}

enum RequestDeviceError: Error {
    case unsupported
    case unauthorized
    case poweredOff
    case userCancelled
    case unknown
}

class RequestDeviceViewController: UIViewController {
    private let navItem = UINavigationItem(title: "Scanning")
    private let rescanItem = UIBarButtonItem(title: "Re-scan", style: .plain, target: nil, action: #selector(rescan))
    private lazy var scanningIndicator: UIBarButtonItem = {
        let activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        activityIndicator.startAnimating()
        return UIBarButtonItem(customView: activityIndicator)
    }()
    private lazy var navBar: UINavigationBar = {
        let view = UINavigationBar(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 56))
        view.setItems([navItem], animated: false)
        return view
    }()
    private lazy var tableView: UITableView = {
        let view = UITableView()
        view.tableFooterView = UIView()
        view.dataSource = self
        view.delegate = self
        view.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return view
    }()

    private var manager: CBCentralManager!
    private var peripherals: [CBPeripheral] = []

    private var options: RequestDeviceOptions!
    private var delegate: RequestDeviceDelegate!
    private var isUserCancelled = true

    convenience init(options: Dictionary<String, Any>, delegate: RequestDeviceDelegate) {
        self.init()
        self.options = RequestDeviceOptions.fromMap(options)
        self.delegate = delegate
        manager = CBCentralManager(delegate: self, queue: .main)
    }

    override func viewDidLoad() {
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        }
        addViews()
        setupConstraints()
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        stop()
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        if isBeingDismissed && isUserCancelled {
            delegate?.requestDevice(self, didFailWithError: .userCancelled)
        }
    }
    
    private func addViews() {
        view.addSubview(navBar)
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: navBar.bottomAnchor).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
    
    @objc private func rescan() {
        start()
    }
    
    @objc private func willResignActive() {
        stop()
    }
    
    private func start() {
        if !manager.isScanning {
            var serviceUUIDs: [CBUUID]? = nil
            if options.filters != nil {
                for filter in options.filters! {
                    if filter.services != nil {
                        serviceUUIDs = []
                        for service in filter.services! {
                            serviceUUIDs!.append(CBUUID(string: service))
                        }
                    }
                    if filter.name != nil {
                        // post filtering
                    }
                    if filter.namePrefix != nil {
                        // post filtering
                    }
                }
            }
            if options.optionalServices != nil {
                for service in options.optionalServices! {
                    // post filtering
                }
            }
            if (options.acceptAllDevices) {
                // nop
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(60) ) { [self] in
                stop()
            }
            peripherals.removeAll()
            tableView.reloadData()
            manager.scanForPeripherals(
                withServices: serviceUUIDs,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
        navItem.rightBarButtonItem = scanningIndicator
    }
    
    private func stop() {
        manager.stopScan()
        navItem.rightBarButtonItem = rescanItem
    }
}

extension RequestDeviceViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let peripheral = peripherals[indexPath.row]
        cell.textLabel?.text = peripheral.name ?? "Unknown (\(peripheral.identifier))"
        return cell
    }
}

extension RequestDeviceViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = peripherals[indexPath.row]
        isUserCancelled = false
        delegate?.requestDevice(self, didRequest: peripheral)
    }
}

extension RequestDeviceViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch(manager.state) {
        case .resetting:
            break
        case .unsupported:
            isUserCancelled = false
            delegate?.requestDevice(self, didFailWithError: .unsupported)
        case .unauthorized:
            isUserCancelled = false
            delegate?.requestDevice(self, didFailWithError: .unauthorized)
        case .poweredOff:
            isUserCancelled = false
            delegate?.requestDevice(self, didFailWithError: .poweredOff)
        case .poweredOn:
            start()
        default:
            isUserCancelled = false
            delegate?.requestDevice(self, didFailWithError: .unknown)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !peripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            peripherals.append(peripheral)
            tableView.reloadData()
        }
    }
}
