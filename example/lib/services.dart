// Source: https://gist.github.com/sam016/4abe921b5a9ee27f67b3686910293026
class Services {
  Services._();

  static const String bluetoothBaseUuidSuffix = '-0000-1000-8000-00805f9b34fb';

  static const Map<int, String> names = {
    0x1800: 'Generic Access',
    0x1801: 'Generic Attribute',
    0x1802: 'Immediate Alert',
    0x1803: 'Link Loss',
    0x1804: 'Tx Power',
    0x1805: 'Current Time Service',
    0x1806: 'Reference Time Update Service',
    0x1807: 'Next DST Change Service',
    0x1808: 'Glucose',
    0x1809: 'Health Thermometer',
    0x180a: 'Device Information',
    0x180d: 'Heart Rate',
    0x180e: 'Phone Alert Status Service',
    0x180f: 'Battery Service',
    0x1810: 'Blood Pressure',
    0x1811: 'Alert Notification Service',
    0x1812: 'Human Interface Device',
    0x1813: 'Scan Parameters',
    0x1814: 'Running Speed and Cadence',
    0x1815: 'Automation IO',
    0x1816: 'Cycling Speed and Cadence',
    0x1818: 'Cycling Power',
    0x1819: 'Location and Navigation',
    0x181a: 'Environmental Sensing',
    0x181b: 'Body Composition',
    0x181c: 'User Data',
    0x181d: 'Weight Scale',
    0x181e: 'Bond Management Service',
    0x181f: 'Continuous Glucose Monitoring',
    0x1820: 'Internet Protocol Support Service',
    0x1821: 'Indoor Positioning',
    0x1822: 'Pulse Oximeter Service',
    0x1823: 'HTTP Proxy',
    0x1824: 'Transport Discovery',
    0x1825: 'Object Transfer Service',
    0x1826: 'Fitness Machine',
    0x1827: 'Mesh Provisioning Service',
    0x1828: 'Mesh Proxy Service',
    0x1829: 'Reconnection Configuration',
  };

  static String lookup(String uuid, {String defaultName = '--'}) {
    final normalizedUuid = uuid.toLowerCase();
    if (normalizedUuid.length != 36 ||
        !normalizedUuid.startsWith('0000') ||
        !normalizedUuid.endsWith(bluetoothBaseUuidSuffix)) {
      return defaultName;
    }

    final assignedNumber = int.tryParse(
      normalizedUuid.substring(4, 8),
      radix: 16,
    );
    return names[assignedNumber] ?? defaultName;
  }

  static String uuid(int assignedNumber) {
    return '0000${assignedNumber.toRadixString(16).padLeft(4, '0')}$bluetoothBaseUuidSuffix';
  }
}
