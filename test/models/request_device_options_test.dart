import 'package:flutter_test/flutter_test.dart';
import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

void main() {
  test('Filter round-trips product data without services', () {
    final filter = Filter(
      namePrefix: 'Sensor',
      productData: ProductData(name: 'Sensor', image: 'assets/sensor.png'),
    );
    final json = filter.toJson();

    expect(json, {
      'namePrefix': 'Sensor',
      'productData': {'name': 'Sensor', 'image': 'assets/sensor.png'},
    });

    final decoded = Filter.fromJson(json);
    expect(decoded.services, isNull);
    expect(decoded.namePrefix, 'Sensor');
    expect(decoded.productData?.name, 'Sensor');
    expect(decoded.productData?.image, 'assets/sensor.png');
    expect(decoded.toJson(), json);
  });

  test('Filter omits absent product data', () {
    final filter = Filter(services: ['180A']);
    expect(filter.toJson(), {
      'services': ['180A'],
    });
    expect(Filter.fromJson(filter.toJson()).productData, isNull);
  });
}
