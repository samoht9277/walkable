import HealthKit
import CoreLocation
import Combine

@MainActor
public final class HealthService: NSObject, ObservableObject {
    public static let shared = HealthService()

    private let store = HKHealthStore()

    #if os(watchOS)
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    #else
    private var workoutBuilder: HKWorkoutBuilder?
    #endif

    private var routeBuilder: HKWorkoutRouteBuilder?

    @Published public var isAuthorized = false
    @Published public var heartRate: Double = 0
    @Published public var activeCalories: Double = 0
    @Published public var distanceWalked: Double = 0

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
    }

    // MARK: - Authorization

    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.walkingSpeed),
            HKQuantityType(.flightsClimbed),
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
        isAuthorized = true
    }

    // MARK: - Workout Session

    #if os(watchOS)
    public func startWalkingWorkout() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .walking
        config.locationType = .outdoor

        session = try HKWorkoutSession(healthStore: store, configuration: config)
        builder = session?.associatedWorkoutBuilder()
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

        session?.delegate = self
        builder?.delegate = self

        let startDate = Date()
        session?.startActivity(with: startDate)
        try await builder?.beginCollection(at: startDate)

        routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
    }

    public func pauseWorkout() {
        session?.pause()
    }

    public func resumeWorkout() {
        session?.resume()
    }

    public func endWorkout() async throws -> HKWorkout? {
        session?.end()
        try await builder?.endCollection(at: Date())

        guard let builder else { return nil }
        let workout: HKWorkout? = try await builder.finishWorkout()

        // Finish the route and attach it to the workout
        if let routeBuilder, let workout {
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }

        self.session = nil
        self.builder = nil
        self.routeBuilder = nil

        return workout
    }
    #else
    // MARK: - iOS Workout (non-live HKWorkoutBuilder)

    public func startWalkingWorkout() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .walking
        config.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: Date())
        self.workoutBuilder = builder

        routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
    }

    public func pauseWorkout() {
        let event = HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: Date(), duration: 0), metadata: nil)
        workoutBuilder?.addWorkoutEvents([event]) { _, _ in }
    }

    public func resumeWorkout() {
        let event = HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: Date(), duration: 0), metadata: nil)
        workoutBuilder?.addWorkoutEvents([event]) { _, _ in }
    }

    public func endWorkout() async throws -> HKWorkout? {
        guard let workoutBuilder else { return nil }

        try await workoutBuilder.endCollection(at: Date())
        let workout: HKWorkout? = try await workoutBuilder.finishWorkout()

        if let routeBuilder, let workout {
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }

        self.workoutBuilder = nil
        self.routeBuilder = nil

        return workout
    }
    #endif

    /// Add a GPS location to the workout route.
    public func addRouteLocation(_ location: CLLocation) {
        routeBuilder?.insertRouteData([location]) { _, _ in }
    }

    // MARK: - Query Walkable Workouts from HealthKit

    /// Fetch walking workouts recorded by this app (source = Walkable bundle ID).
    public func fetchWalkableWorkouts(since date: Date = .distantPast) async throws -> [HKWorkout] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let walkPredicate = HKQuery.predicateForWorkouts(with: .walking)
        let datePredicate = HKQuery.predicateForSamples(withStart: date, end: nil)
        let sourcePredicate = HKQuery.predicateForObjects(from: .default())
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [walkPredicate, datePredicate, sourcePredicate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: compound,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    /// Fetch the GPS route for a specific workout.
    public func fetchWorkoutRoute(_ workout: HKWorkout) async throws -> [CLLocation] {
        let routes = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkoutRoute], Error>) in
            let query = HKAnchoredObjectQuery(
                type: HKSeriesType.workoutRoute(),
                predicate: HKQuery.predicateForObjects(from: workout),
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, _, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }

        guard let route = routes.first else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            var locations = [CLLocation]()
            let routeQuery = HKWorkoutRouteQuery(route: route) { _, batch, done, error in
                if let error { continuation.resume(throwing: error); return }
                if let batch { locations.append(contentsOf: batch) }
                if done { continuation.resume(returning: locations) }
            }
            store.execute(routeQuery)
        }
    }

    // MARK: - Delete Workout

    /// Delete a workout from HealthKit by its UUID.
    public func deleteWorkout(id: UUID) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let predicate = HKQuery.predicateForObject(with: id)
        let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: results ?? [])
            }
            store.execute(query)
        }

        for workout in workouts {
            try await store.delete(workout)
        }
    }

    // MARK: - Heart Rate Samples

    public func heartRateSamples(from startDate: Date, to endDate: Date) async throws -> [TimedSample] {
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = SortDescriptor(\HKQuantitySample.startDate)

        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [sortDescriptor]
        )
        let samples = try await query.result(for: store)
        return samples.map { sample in
            TimedSample(
                date: sample.startDate,
                value: sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            )
        }
    }

    // MARK: - Stats Queries

    /// Get total walking distance for a date range.
    public func totalDistance(from startDate: Date, to endDate: Date) async throws -> Double {
        try await querySum(type: HKQuantityType(.distanceWalkingRunning), from: startDate, to: endDate, unit: .meter())
    }

    /// Get total calories burned from walking workouts in a date range.
    public func totalCalories(from startDate: Date, to endDate: Date) async throws -> Double {
        try await querySum(type: HKQuantityType(.activeEnergyBurned), from: startDate, to: endDate, unit: .kilocalorie())
    }

    /// Count consecutive days (ending today) with a walking workout.
    public func currentStreak() async throws -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today

        while true {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!
            let hasWorkout = try await hasWalkingWorkout(from: checkDate, to: nextDay)
            if hasWorkout {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        return streak
    }

    private func hasWalkingWorkout(from startDate: Date, to endDate: Date) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForWorkouts(with: .walking)
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])

            let query = HKSampleQuery(sampleType: .workoutType(), predicate: compound, limit: 1, sortDescriptors: nil) { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (results?.count ?? 0) > 0)
            }
            store.execute(query)
        }
    }

    private func querySum(type: HKQuantityType, from startDate: Date, to endDate: Date, unit: HKUnit) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}

#if os(watchOS)
extension HealthService: @preconcurrency HKWorkoutSessionDelegate {
    public nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}

    public nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

extension HealthService: @preconcurrency HKLiveWorkoutBuilderDelegate {
    public nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    public nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            switch quantityType {
            case HKQuantityType(.heartRate):
                if let stats = workoutBuilder.statistics(for: quantityType) {
                    let bpm = stats.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                    Task { @MainActor in self.heartRate = bpm }
                }
            case HKQuantityType(.activeEnergyBurned):
                if let stats = workoutBuilder.statistics(for: quantityType) {
                    let cals = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    Task { @MainActor in self.activeCalories = cals }
                }
            case HKQuantityType(.distanceWalkingRunning):
                if let stats = workoutBuilder.statistics(for: quantityType) {
                    let meters = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                    Task { @MainActor in self.distanceWalked = meters }
                }
            default:
                break
            }
        }
    }
}
#endif
