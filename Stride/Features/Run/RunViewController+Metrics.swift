//
//  RunViewController+Metrics.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import Foundation // Foundation framework'ünü projeye dahil eder

extension RunViewController { // RunViewController sınıfına genişletme ekler

    // MARK: - Formatting helpers

    func formatHMS(_ seconds: Int) -> String { // Saniye cinsinden süreyi saat:dakika:saniye formatına çevirir
        let h = seconds / 3600 // Saat değerini hesaplar
        let m = (seconds % 3600) / 60 // Dakika değerini hesaplar
        let s = seconds % 60 // Saniye değerini hesaplar
        return String(format: "%01d:%02d:%02d", h, m, s) // Formatlanmış süreyi döndürür
    }

    func formatPace(secondsPerKm: Double) -> String { // Ortalama tempoyu seçili birime göre formatlar (/km veya /mi)
        let unitRaw = UserDefaults.standard.string(forKey: "trackly.distanceUnit") ?? "kilometers"
        let isMiles = (unitRaw == "miles")

        // Convert sec/km -> sec/mi if needed
        let secondsPerUnit: Double
        let suffix: String
        if isMiles {
            secondsPerUnit = secondsPerKm * (1000.0 / 1609.344)
            suffix = "/mi"
        } else {
            secondsPerUnit = secondsPerKm
            suffix = "/km"
        }

        guard secondsPerUnit.isFinite, secondsPerUnit > 0 else { return "0:00 \(suffix)" }
        let m = Int(secondsPerUnit) / 60
        let s = Int(secondsPerUnit) % 60
        return String(format: "%d:%02d %@", m, s, suffix)
    }

    func hasPlistKey(_ key: String) -> Bool { // Info.plist dosyasında belirtilen anahtarın varlığını kontrol eder
        return Bundle.main.object(forInfoDictionaryKey: key) != nil // Anahtar varsa true döner, yoksa false
    }

    func currentElapsedSeconds() -> Int { // Koşu başlangıcından itibaren geçen saniyeyi hesaplar
        guard let start = runStartDate else { return 0 } // Başlangıç tarihi yoksa 0 döndürür
        return Int(Date().timeIntervalSince(start)) // Başlangıç tarihinden itibaren geçen saniyeyi döndürür
    }

    func updateMetrics() { // Koşu ile ilgili metrikleri günceller
        // Süre
        let elapsed = currentElapsedSeconds() // Geçen süreyi alır
        timeValue.text = formatHMS(elapsed) // Süreyi formatlayıp ekranda gösterir

        // Mesafe (km / mi)
        let unitRaw = UserDefaults.standard.string(forKey: "trackly.distanceUnit") ?? "kilometers"
        let isMiles = (unitRaw == "miles")

        let km = totalDistanceMeters / 1000.0 // Kalori için km her zaman lazım
        let distanceValue: Double
        let distanceSuffix: String

        if isMiles {
            distanceValue = totalDistanceMeters / 1609.344
            distanceSuffix = "mi"
        } else {
            distanceValue = km
            distanceSuffix = "km"
        }

        distValue.text = String(format: "%.2f %@", distanceValue, distanceSuffix)

        // Tempo (ortalama pace)
        // Pace hesaplamasını da seçili birim başına yap (sonra formatPace sec/km'den sec/mi'ye çevirebiliyor ama burada da doğru hesaplayalım)
        let distancePerUnit = max(0.0, distanceValue)
        let secondsPerUnit = distancePerUnit > 0 ? Double(elapsed) / distancePerUnit : 0

        if isMiles {
            // secondsPerUnit is already sec/mi; convert to sec/km for formatPace helper
            let secPerKm = secondsPerUnit * (1609.344 / 1000.0)
            paceValue.text = formatPace(secondsPerKm: secPerKm)
        } else {
            // secondsPerUnit == sec/km
            paceValue.text = formatPace(secondsPerKm: secondsPerUnit)
        }

        // Kalori (yaklaşık) - km bazlı
        let kcal = km * userWeightKg * kcalPerKmPerKg
        kcalValue.text = String(Int(kcal.rounded()))
    }
}
