#if canImport(AppIntents) && canImport(ActivityKit)
import AppIntents

#if os(iOS)
@available(iOS 16.1, *)
public struct TogglePauseIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Toggle Pause"
    public static let description: IntentDescription = "Pause or resume the current walk"

    public init() {}

    public func perform() async throws -> some IntentResult {
        let name = CFNotificationName("com.walkable.togglePause" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            name,
            nil,
            nil,
            true
        )
        return .result()
    }
}
#endif
#endif
