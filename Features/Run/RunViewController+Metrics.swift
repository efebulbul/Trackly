//
//  RunViewController+Location.swift
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

    func formatPace(secondsPerKm: Double) -> String { // Km başına saniye cinsinden tempoyu dakika:saniye formatına çevirir
        guard secondsPerKm.isFinite, secondsPerKm > 0 else { return "0:00 /km" } // Geçerli ve pozitif tempo değilse varsayılan metni döndürür
        let m = Int(secondsPerKm) / 60 // Dakika kısmını hesaplar
        let s = Int(secondsPerKm) % 60 // Saniye kısmını hesaplar
        return String(format: "%d:%02d /km", m, s) // Formatlanmış tempo metnini döndürür
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

        // Mesafe (km)
        let km = totalDistanceMeters / 1000.0 // Toplam mesafeyi kilometre cinsine çevirir
        distValue.text = String(format: "%.2f km", km) // Mesafeyi ekranda gösterir

        // Tempo (ortalama pace)
        let paceSecPerKm = km > 0 ? Double(elapsed) / km : 0 // Ortalama tempo saniye/km olarak hesaplanır
        paceValue.text = formatPace(secondsPerKm: paceSecPerKm) // Tempo formatlanıp ekranda gösterilir

        // Kalori (yaklaşık)
        let kcal = km * userWeightKg * kcalPerKmPerKg // Yakılan kalori yaklaşık olarak hesaplanır
        kcalValue.text = String(Int(kcal.rounded())) // Kalori değeri ekranda gösterilir
    }
}
