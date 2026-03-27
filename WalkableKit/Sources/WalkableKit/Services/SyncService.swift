@preconcurrency import WatchConnectivity
import SwiftData
import Combine

public enum SyncOperation: String, Codable, Sendable {
    case create, update, delete
}

public struct SyncPayload: Codable, Sendable {
    public let operation: SyncOperation
    public let routeId: String
    public let name: String?
    public let distance: Double?
    public let estimatedDuration: TimeInterval?
    public let waypoints: [SyncWaypoint]?
    public let polylineCoordinates: [CodableCoordinate]?

    public init(
        operation: SyncOperation,
        routeId: String,
        name: String? = nil,
        distance: Double? = nil,
        estimatedDuration: TimeInterval? = nil,
        waypoints: [SyncWaypoint]? = nil,
        polylineCoordinates: [CodableCoordinate]? = nil
    ) {
        self.operation = operation
        self.routeId = routeId
        self.name = name
        self.distance = distance
        self.estimatedDuration = estimatedDuration
        self.waypoints = waypoints
        self.polylineCoordinates = polylineCoordinates
    }
}

public struct SyncWaypoint: Codable, Sendable {
    public let index: Int
    public let latitude: Double
    public let longitude: Double
    public let label: String?

    public init(index: Int, latitude: Double, longitude: Double, label: String? = nil) {
        self.index = index
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
    }
}

public struct SessionSyncPayload: Codable, Sendable {
    public let routeId: String
    public let startedAt: Date
    public let completedAt: Date
    public let totalDistance: Double
    public let totalDuration: TimeInterval
    public let calories: Double
    public let elevationGain: Double
    public let avgPace: Double
    public let legSplits: [SyncLegSplit]
}

public struct SyncLegSplit: Codable, Sendable {
    public let fromWaypointIndex: Int
    public let toWaypointIndex: Int
    public let distance: Double
    public let duration: TimeInterval
    public let pace: Double
}

@MainActor
public final class SyncService: NSObject, ObservableObject {
    public static let shared = SyncService()

    @Published public var isReachable = false

    /// Called on the receiving side when a route sync arrives.
    public let routeSyncReceived = PassthroughSubject<SyncPayload, Never>()

    /// Called on the phone when a walk session arrives from the watch.
    public let sessionSyncReceived = PassthroughSubject<SessionSyncPayload, Never>()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Send Route to Watch

    public func syncRoute(_ route: Route, operation: SyncOperation) {
        let waypoints = route.sortedWaypoints.map {
            SyncWaypoint(index: $0.index, latitude: $0.latitude, longitude: $0.longitude, label: $0.label)
        }

        var polylineCoords: [CodableCoordinate]?
        if let data = route.polylineData {
            polylineCoords = try? JSONDecoder().decode([CodableCoordinate].self, from: data)
        }

        let payload = SyncPayload(
            operation: operation,
            routeId: route.id.uuidString,
            name: route.name,
            distance: route.distance,
            estimatedDuration: route.estimatedDuration,
            waypoints: waypoints,
            polylineCoordinates: polylineCoords
        )

        guard let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        WCSession.default.transferUserInfo(["routeSync": dict])
    }

    /// Set the currently active route for quick-launch on Watch.
    public func setActiveRoute(_ route: Route?) {
        var context: [String: Any] = [:]
        if let route {
            context["activeRouteId"] = route.id.uuidString
            context["activeRouteName"] = route.name
        }
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Send Walk Session to Phone (from Watch)

    public func syncWalkSession(_ payload: SessionSyncPayload) {
        guard let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        WCSession.default.transferUserInfo(["sessionSync": dict])
    }
}

extension SyncService: @preconcurrency WCSessionDelegate {
    public nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    #if os(iOS)
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    public nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let routeDict = userInfo["routeSync"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: routeDict),
           let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) {
            Task { @MainActor in
                routeSyncReceived.send(payload)
            }
        }

        if let sessionDict = userInfo["sessionSync"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: sessionDict),
           let payload = try? JSONDecoder().decode(SessionSyncPayload.self, from: data) {
            Task { @MainActor in
                sessionSyncReceived.send(payload)
            }
        }
    }

    public nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }
}
