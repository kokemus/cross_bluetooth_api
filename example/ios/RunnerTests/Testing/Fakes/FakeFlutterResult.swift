import Flutter

final class FakeFlutterResult {
    private(set) var value: Any?

    func handler(_ value: Any?) {
        self.value = value
    }
}
