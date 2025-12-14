//
//  HealthKitManager.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import Foundation
import HealthKit

/// HealthKit ile tüm iletişimi yöneten yardımcı sınıf.
/// Şimdilik: sadece izin ister + bugünün adım sayısını çeker.
final class HealthKitManager {

    // Singleton (tek instance)
    static let shared = HealthKitManager()

    /// iOS'un HealthKit store'u
    let healthStore = HKHealthStore()

    /// Uygulamanın okuyacağı veri tipleri (şimdilik: Adım sayısı)
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepsType)
        }
        // İleride ekleyebiliriz:
        // distanceWalkingRunning, activeEnergyBurned vs.
        return types
    }

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
            completion(false, NSError(domain: "HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Health data not available on this device"]))
            return
        }

        // Sadece okuma (read) istiyoruz, şimdilik yazma (share) yok.
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    // MARK: - Bugünkü adım sayısı

    /// Bugün (00:00 – şimdi) arası toplam adım sayısını çeker.
    func fetchTodayStepCount(completion: @escaping (Double?, Error?) -> Void) {
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion(nil, NSError(domain: "HealthKit", code: -2, userInfo: [NSLocalizedDescriptionKey: "Step type not available"]))
            return
        }

        let calendar = Calendar.current
        let now = Date()
        guard let startOfDay = calendar.startOfDay(for: now) as Date? else {
            completion(nil, NSError(domain: "HealthKit", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not compute start of day"]))
            return
        }

        // 00:00 – şimdi arası
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        // Toplama (sum) sorgusu
        let query = HKStatisticsQuery(quantityType: stepsType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }

            let sum = stats?.sumQuantity()
            let steps = sum?.doubleValue(for: HKUnit.count())

            DispatchQueue.main.async {
                completion(steps ?? 0, nil)
            }
        }

        healthStore.execute(query)
    }
}
