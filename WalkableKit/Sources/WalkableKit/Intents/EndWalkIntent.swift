#if canImport(AppIntents) && canImport(ActivityKit)
import AppIntents

#if os(iOS)
@available(iOS 16.1, *)
public struct EndWalkIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "End Walk"
    public static let description: IntentDescription = "End the current walk and save progress"

    public init() {}

    public func perform() async throws -> some IntentResult {
        let name = CFNotificationName("com.walkable.endWalk" as CFString)
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
