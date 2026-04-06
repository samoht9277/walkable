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
    public let gpsTrack: [CodableCoordinate]?

    public init(
        routeId: String,
        startedAt: Date,
        completedAt: Date,
        totalDistance: Double,
        totalDuration: TimeInterval,
        calories: Double,
        elevationGain: Double,
        avgPace: Double,
        legSplits: [SyncLegSplit],
        gpsTrack: [CodableCoordinate]? = nil
    ) {
        self.routeId = routeId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.totalDistance = totalDistance
        self.totalDuration = totalDuration
        self.calories = calories
        self.elevationGain = elevationGain
        self.avgPace = avgPace
        self.gpsTrack = gpsTrack
        self.legSplits = legSplits
    }
}

public struct SyncLegSplit: Codable, Sendable {
    public let fromWaypointIndex: Int
    public let toWaypointIndex: Int
    public let distance: Double
    public let duration: TimeInterval
    public let pace: Double

    public init(fromWaypointIndex: Int, toWaypointIndex: Int, distance: Double, duration: TimeInterval, pace: Double) {
        self.fromWaypointIndex = fromWaypointIndex
        self.toWaypointIndex = toWaypointIndex
        self.distance = distance
        self.duration = duration
        self.pace = pace
    }
}

@MainActor
public final class SyncService: NSObject, ObservableObject {
    public static let shared = SyncService()

    @Published public var isReachable = false

    /// Called on the receiving side when a route sync arrives.
    public let routeSyncReceived = PassthroughSubject<SyncPayload, Never>()

    /// Called on the phone when a walk session arrives from the watch.
    public let sessionSyncReceived = PassthroughSubject<SessionSyncPayload, Never>()

    @Published public var activationState: WCSessionActivationState = .notActivated
    @Published public var isPaired = false
    @Published public var isWatchAppInstalled = false
    @Published public var syncStatus: String = "Initializing..."

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            syncStatus = "Activating session..."
        } else {
            syncStatus = "WCSession not supported"
        }
    }

    // MARK: - Sync All Routes to Watch

    /// Push all routes to Watch via applicationContext (persistent, always available).
    public func syncAllRoutes(_ routes: [Route]) {
        guard WCSession.default.activationState == .activated else {
            syncStatus = "Sync failed: not activated"
            return
        }
        #if os(iOS)
        guard WCSession.default.isWatchAppInstalled else {
            syncStatus = "Sync failed: Watch app not installed"
            return
        }
        #endif

        var allPayloads = [[String: Any]]()
        for route in routes {
            let waypoints = route.sortedWaypoints.map {
                SyncWaypoint(index: $0.index, latitude: $0.latitude, longitude: $0.longitude, label: $0.label)
            }
            var polylineCoords: [CodableCoordinate]?
            if let data = route.polylineData {
                polylineCoords = try? JSONDecoder().decode([CodableCoordinate].self, from: data)
            }
            let payload = SyncPayload(
                operation: .create,
                routeId: route.id.uuidString,
                name: route.name,
                distance: route.distance,
                estimatedDuration: route.estimatedDuration,
                waypoints: waypoints,
                polylineCoordinates: polylineCoords
            )
            if let data = try? JSONEncoder().encode(payload),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                allPayloads.append(dict)
            }
        }
        // Pack all routes into applicationContext — persistent, Watch reads on launch
        do {
            try WCSession.default.updateApplicationContext(["allRoutes": allPayloads])
            syncStatus = "Sent \(routes.count) routes via context"
        } catch {
            syncStatus = "Context error: \(error.localizedDescription)"
        }
        // Also send via transferUserInfo as backup
        for dict in allPayloads {
            WCSession.default.transferUserInfo(["routeSync": dict])
        }
        syncStatus += " + queued \(allPayloads.count) transfers"
    }

    /// Fired when the Watch becomes reachable so the phone can push all routes.
    public let watchBecameReachable = PassthroughSubject<Void, Never>()

    /// Fired on Watch when applicationContext arrives with all routes.
    public let allRoutesSyncReceived = PassthroughSubject<[SyncPayload], Never>()

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

    // MARK: - Watch-Created Route Sync (Watch → Phone)

    /// Send a route created on Watch to the phone via transferUserInfo (queued delivery).
    public func syncWatchCreatedRoute(_ payload: SyncPayload) {
        guard let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        WCSession.default.transferUserInfo(["watchCreatedRoute": dict])
    }

    /// Called on the phone when a Watch-created route arrives.
    public let watchCreatedRouteReceived = PassthroughSubject<SyncPayload, Never>()

    // MARK: - Phone → Watch Walk Handoff

    /// Send a "start walk" command to the Watch with the route data (immediate delivery).
    public func startWalkOnWatch(route: Route) {
        let waypoints = route.sortedWaypoints.map {
            SyncWaypoint(index: $0.index, latitude: $0.latitude, longitude: $0.longitude, label: $0.label)
        }

        var polylineCoords: [CodableCoordinate]?
        if let data = route.polylineData {
            polylineCoords = try? JSONDecoder().decode([CodableCoordinate].self, from: data)
        }

        let payload = SyncPayload(
            operation: .create,
            routeId: route.id.uuidString,
            name: route.name,
            distance: route.distance,
            estimatedDuration: route.estimatedDuration,
            waypoints: waypoints,
            polylineCoordinates: polylineCoords
        )

        guard let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let message: [String: Any] = ["startWalkOnWatch": dict]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(message)
            }
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    /// Called on Watch when the phone requests a walk start.
    public let startWalkRequested = PassthroughSubject<SyncPayload, Never>()

    /// Notify the phone that a walk started or ended on Watch.
    public func notifyPhoneWalkStatus(routeId: String, status: WalkHandoffStatus) {
        let dict: [String: Any] = [
            "watchWalkStatus": [
                "routeId": routeId,
                "status": status.rawValue
            ]
        ]
        WCSession.default.sendMessage(dict, replyHandler: nil) { _ in
            // Fall back to transferUserInfo if not reachable
            WCSession.default.transferUserInfo(dict)
        }
    }

    /// Called on the phone when Watch reports walk status.
    public let watchWalkStatusReceived = PassthroughSubject<(routeId: String, status: WalkHandoffStatus), Never>()
}

public enum WalkHandoffStatus: String, Codable, Sendable {
    case started, ended
}

extension SyncService: @preconcurrency WCSessionDelegate {
    public nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.activationState = state
            self.isReachable = session.isReachable
            #if os(iOS)
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.syncStatus = "Active: paired=\(session.isPaired) installed=\(session.isWatchAppInstalled) reachable=\(session.isReachable)"
            #else
            self.syncStatus = "Active: reachable=\(session.isReachable)"
            #endif
            if let error {
                self.syncStatus = "Error: \(error.localizedDescription)"
            }
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

        if let routeDict = userInfo["watchCreatedRoute"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: routeDict),
           let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) {
            Task { @MainActor in
                watchCreatedRouteReceived.send(payload)
            }
        }

        if let statusDict = userInfo["watchWalkStatus"] as? [String: Any],
           let routeId = statusDict["routeId"] as? String,
           let rawStatus = statusDict["status"] as? String,
           let status = WalkHandoffStatus(rawValue: rawStatus) {
            Task { @MainActor in
                watchWalkStatusReceived.send((routeId: routeId, status: status))
            }
        }

        // Handle startWalkOnWatch via transferUserInfo fallback
        if let routeDict = userInfo["startWalkOnWatch"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: routeDict),
           let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) {
            Task { @MainActor in
                startWalkRequested.send(payload)
            }
        }
    }

    public nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let routeDict = message["startWalkOnWatch"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: routeDict),
           let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) {
            Task { @MainActor in
                startWalkRequested.send(payload)
            }
        }

        if let statusDict = message["watchWalkStatus"] as? [String: Any],
           let routeId = statusDict["routeId"] as? String,
           let rawStatus = statusDict["status"] as? String,
           let status = WalkHandoffStatus(rawValue: rawStatus) {
            Task { @MainActor in
                watchWalkStatusReceived.send((routeId: routeId, status: status))
            }
        }
    }

    public nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let routeDicts = applicationContext["allRoutes"] as? [[String: Any]] {
            var payloads = [SyncPayload]()
            for dict in routeDicts {
                if let data = try? JSONSerialization.data(withJSONObject: dict),
                   let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) {
                    payloads.append(payload)
                }
            }
            Task { @MainActor in
                allRoutesSyncReceived.send(payloads)
            }
        }
    }

    public nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            let wasReachable = isReachable
            isReachable = session.isReachable
            if !wasReachable && session.isReachable {
                watchBecameReachable.send()
            }
        }
    }
}
