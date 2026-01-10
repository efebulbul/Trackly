//
//  HealthKitManager.swift
//  Stride
//
//  Created by EfeBülbül on 5.11.2025.
//

import Foundation
import HealthKit

/// HealthKit ile iletişimi yöneten yardımcı sınıf (şu an aktif kullanım yok).
final class HealthKitManager {

    // Singleton (tek instance)
    static let shared = HealthKitManager()

    /// iOS'un HealthKit store'u
    let healthStore = HKHealthStore()

    private init() {}

    // MARK: - Destek kontrolü

    /// Bu cihaz HealthKit destekliyor mu?
    func isHealthDataAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - İzin İsteme

    /// Kullanıcıdan Health verilerini okuma izni ister.
    /// Bu fonksiyonu genelde ayarlardan veya ilk girişte çağırırsın.
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "Health data is not available on this device."]))
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            completion(success, error)
        }
    }

    // MARK: - Models

    struct HourlyStat: Identifiable {
        let id = UUID()
        let hour: Int // 0...23
        let value: Double
    }

    // MARK: - Public Queries

    func fetchTodayActiveEnergyKcal(completion: @escaping (Result<Double, Error>) -> Void) {
        fetchTodaySum(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            completion: completion
        )
    }

    func fetchHourlyActiveEnergyKcalToday(completion: @escaping (Result<[HourlyStat], Error>) -> Void) {
        fetchHourlyStatsToday(identifier: .activeEnergyBurned, unit: .kilocalorie(), completion: completion)
    }

    func fetchTodaySteps(completion: @escaping (Result<Double, Error>) -> Void) {
        fetchTodaySum(
            identifier: .stepCount,
            unit: .count(),
            completion: completion
        )
    }

    func fetchTodayDistanceKm(completion: @escaping (Result<Double, Error>) -> Void) {
        fetchTodaySum(
            identifier: .distanceWalkingRunning,
            unit: .meterUnit(with: .kilo),
            completion: completion
        )
    }

    func fetchHourlyStepsToday(completion: @escaping (Result<[HourlyStat], Error>) -> Void) {
        fetchHourlyStatsToday(identifier: .stepCount, unit: .count(), completion: completion)
    }

    func fetchHourlyDistanceKmToday(completion: @escaping (Result<[HourlyStat], Error>) -> Void) {
        fetchHourlyStatsToday(identifier: .distanceWalkingRunning, unit: .meterUnit(with: .kilo), completion: completion)
    }

    // MARK: - Internals

    private func fetchTodaySum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping (Result<Double, Error>) -> Void
    ) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(.failure(NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported quantity type."])))
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error {
                completion(.failure(error))
                return
            }

            let sum = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
            completion(.success(sum))
        }

        healthStore.execute(query)
    }

    private func fetchHourlyStatsToday(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping (Result<[HourlyStat], Error>) -> Void
    ) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(.failure(NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported quantity type."])))
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endDate = Date()

        var interval = DateComponents()
        interval.hour = 1

        let anchorComponents = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        let anchorDate = calendar.date(from: anchorComponents) ?? startOfDay

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endDate, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: anchorDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, error in
            if let error {
                completion(.failure(error))
                return
            }

            var buckets: [HourlyStat] = []
            results?.enumerateStatistics(from: startOfDay, to: endDate) { stat, _ in
                let hour = calendar.component(.hour, from: stat.startDate)
                let value = stat.sumQuantity()?.doubleValue(for: unit) ?? 0
                buckets.append(HourlyStat(hour: hour, value: value))
            }

            // Ensure 0...23 exists (nice for charts)
            let map = Dictionary(uniqueKeysWithValues: buckets.map { ($0.hour, $0.value) })
            let full = (0...23).map { HourlyStat(hour: $0, value: map[$0] ?? 0) }
            completion(.success(full))
        }

        healthStore.execute(query)
    }
}
