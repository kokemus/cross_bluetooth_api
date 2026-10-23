import 'package:flutter_test/flutter_test.dart';
import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

void main() {
  test('Filter round-trips manufacturer data without services', () {
    final options = RequestDeviceOptions(
      filters: [
        Filter(
          manufacturerData: [
            ManufacturerData(
              companyIdentifier: 0x000C,
              dataPrefix: [0x01, 0x02],
              mask: [0xFF, 0xF0],
            ),
            ManufacturerData(companyIdentifier: 0x004C),
          ],
        ),
      ],
    );
    final json = options.toJson();
    expect(json, {
      'filters': [
        {
          'manufacturerData': [
            {
              'companyIdentifier': 12,
              'dataPrefix': [1, 2],
              'mask': [255, 240],
            },
            {'companyIdentifier': 76},
          ],
        },
      ],
    });
    final decoded = Filter.fromJson(json['filters'].single);
    expect(decoded.services, isNull);
    expect(decoded.manufacturerData!.first.companyIdentifier, 12);
    expect(decoded.manufacturerData!.first.dataPrefix, [1, 2]);
    expect(decoded.manufacturerData!.first.mask, [255, 240]);
    expect(decoded.manufacturerData!.last.dataPrefix, isNull);
    expect(decoded.manufacturerData!.last.mask, isNull);
    expect(decoded.toJson(), json['filters'].single);
  });

  test('Filter omits absent manufacturer data and preserves empty lists', () {
    expect(Filter(name: 'Sensor').toJson(), {'name': 'Sensor'});
    expect(Filter.fromJson({'name': 'Sensor'}).manufacturerData, isNull);
    final filter = Filter(manufacturerData: []);
    expect(Filter.fromJson(filter.toJson()).manufacturerData, isEmpty);
    final data = ManufacturerData(
      companyIdentifier: 12,
      dataPrefix: [],
      mask: [],
    );
    expect(ManufacturerData.fromJson(data.toJson()).toJson(), {
      'companyIdentifier': 12,
      'dataPrefix': [],
      'mask': [],
    });
  });

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
