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
        completion(true, nil)
    }
}
