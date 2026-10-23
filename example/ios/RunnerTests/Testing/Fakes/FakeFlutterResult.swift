import Flutter

final class FakeFlutterResult {
    private(set) var value: Any?
    private(set) var replyCount = 0
    var onReply: (() -> Void)?

    func handler(_ value: Any?) {
        self.value = value
        replyCount += 1
        onReply?()
    }
}
