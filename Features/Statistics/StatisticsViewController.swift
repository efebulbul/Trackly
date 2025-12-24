//
//  StatisticsViewController.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//


import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

import SwiftUI
#Preview {
    ViewControllerPreview {
        StatisticsViewController()
    }
}

extension StatisticsViewController {

        // MARK: - Data + Chart // Bu bölümün veri + grafik işlemleri olduğunu belirtir
        func reloadChart() { // Seçilen periyoda göre veriyi çekip grafikleri yeniden yükler
            let cal = Calendar.current // Tarih hesaplamaları için mevcut takvimi alır
            let today = Date() // Bugünün tarih-saat bilgisini alır

            var rangeStart: Date // Seçilen periyot aralığının başlangıç tarihini tutar
            var rangeEnd: Date // Seçilen periyot aralığının bitiş tarihini tutar

            // 1) Seçilen döneme göre tarih aralığı (week / month / year) // Periyoda göre başlangıç-bitiş aralığı hesaplanır
            switch period { // Kullanıcının seçtiği period değerine göre dallanır
            case .week: // Haftalık görünüm seçildiyse
                let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: today) ?? today // Haftayı offset’e göre ileri/geri kaydırılmış referans tarih üretir
                rangeStart = startOfWeek(for: base) // Referans tarihin haftasının pazartesi gününü başlangıç yapar
                rangeEnd = cal.date(byAdding: .day, value: 7, to: rangeStart) ?? rangeStart // Başlangıçtan 7 gün sonrasını bitiş yapar

            case .month: // Aylık görünüm seçildiyse
                let base = cal.date(byAdding: .month, value: monthOffset, to: today) ?? today // Ayı offset’e göre ileri/geri kaydırılmış referans tarih üretir
                let comps = cal.dateComponents([.year, .month], from: base) // Ayın ilk gününü bulmak için yıl+ay bileşenlerini alır
                rangeStart = cal.date(from: comps) ?? base // Ayın başlangıç tarihini üretir (fallback base)
                rangeEnd = cal.date(byAdding: .month, value: 1, to: rangeStart) ?? rangeStart // Bir ay sonrasını bitiş yapar

            case .year: // Yıllık görünüm seçildiyse
                let base = cal.date(byAdding: .year, value: yearOffset, to: today) ?? today // Yılı offset’e göre ileri/geri kaydırılmış referans tarih üretir
                let comps = cal.dateComponents([.year], from: base) // Yılın ilk gününü bulmak için sadece yıl bileşenini alır
                rangeStart = cal.date(from: comps) ?? base // Yıl başlangıç tarihini üretir (fallback base)
                rangeEnd = cal.date(byAdding: .year, value: 1, to: rangeStart) ?? rangeStart // Bir yıl sonrasını bitiş yapar
            } // period switch biter

            // 2) Üstteki tarih başlığı (Hafta / Ay / Yıl etiketi) // UI’daki period başlığını hazırlar
            let df = DateFormatter() // Tarihi string’e çevirmek için formatter oluşturur
            df.locale = Locale(identifier: "tr_TR") // Ay/gün adlarının Türkçe çıkmasını sağlar

            switch period { // Başlık formatını period’a göre değiştirir
            case .week: // Haftalık başlık
                df.dateFormat = "d MMM" // Örn: 22 Ara formatı
                let endTitle = cal.date(byAdding: .day, value: 6, to: rangeStart) ?? rangeStart // Haftanın son gününü (6 gün sonrası) hesaplar
                periodLabel.text = "\(df.string(from: rangeStart)) – \(df.string(from: endTitle))" // Başlangıç–bitiş aralığını label’a yazar

            case .month: // Aylık başlık
                df.dateFormat = "LLLL yyyy" // Örn: Aralık 2025 formatı
                periodLabel.text = df.string(from: rangeStart) // Ay+yıl başlığını label’a yazar

            case .year: // Yıllık başlık
                df.dateFormat = "yyyy" // Sadece yıl formatı
                periodLabel.text = df.string(from: rangeStart) // Yıl bilgisini label’a yazar
            } // period switch biter

            // 3) Veriyi Firestore'dan çek (login zorunlu) // Firestore’dan koşu verisini çekerek istatistik üretir
            #if canImport(FirebaseAuth) // FirebaseAuth modülü varsa bu blok derlenir
            guard Auth.auth().currentUser != nil else { // Kullanıcı giriş yapmamışsa
                // ✅ Login zorunlu: kullanıcı yoksa boş göster // Login yokken boş durum render edilir
                renderChartsAndCards(with: [], cal: cal, rangeStart: rangeStart, rangeEnd: rangeEnd) // Boş listeyle UI’yı çiz
                return // reloadChart fonksiyonundan çık
            } // guard biter

            RunFirestoreStore.shared.fetchRuns { [weak self] result in // Firestore’dan koşuları async olarak çeker
                guard let self = self else { return } // self deallocate olduysa işlemi iptal eder
                DispatchQueue.main.async { // UI güncellemeleri ana thread’de yapılır
                    let runs: [Run] // Bu aralıkta kullanılacak koşu listesi
                    switch result { // Fetch sonucuna göre dallanır
                    case .success(let fetched): // Başarılı sonuç geldiyse
                        runs = fetched.filter { $0.date >= rangeStart && $0.date < rangeEnd } // Sadece seçilen tarih aralığındaki koşuları filtreler
                    case .failure: // Hata olduysa
                        runs = [] // Boş listeye düşer
                    } // result switch biter
                    self.renderChartsAndCards(with: runs, cal: cal, rangeStart: rangeStart, rangeEnd: rangeEnd) // Hesaplayıp grafikleri/kartları günceller
                } // main queue biter
            } // fetchRuns completion biter
            #else // FirebaseAuth yoksa
            // FirebaseAuth yoksa (ör. farklı target/konfig), istatistikleri boş göster. // Auth olmayan build için fallback
            renderChartsAndCards(with: [], cal: cal, rangeStart: rangeStart, rangeEnd: rangeEnd) // Boş veriyle UI’yı render eder
            #endif // Koşullu derleme biter
        } // reloadChart biter

        // MARK: - Render (shared) // UI render/hazırlama fonksiyonlarının bölümü
        private func renderChartsAndCards(with runs: [Run], cal: Calendar, rangeStart: Date, rangeEnd: Date) { // Koşuları bucket’lara ayırıp grafikleri/kartları günceller

            // 4) Grafik bucket dizileri (x ekseni label + y değerleri) // Grafiklerde kullanılacak label ve değer dizilerini hazırlar
            var labels: [String] = [] // X ekseni label’ları
            var kcalValues: [Double] = [] // Kalori değerleri
            var distValues: [Double] = [] // Mesafe (km veya mi) değerleri (seçime göre)
            var durationValues: [Int] = [] // Süre (sn) değerleri
            var pacePerBucketSec: [Double] = []   // her bucket için ortalama pace (s/km veya s/mi) (seçime göre)

            let unitRaw = UserDefaults.standard.string(forKey: "trackly.distanceUnit") ?? "kilometers"
            let isMiles = (unitRaw == "miles")
            let distUnitSuffix = isMiles ? "mi" : "km"

            func convertKmToSelectedUnit(_ km: Double) -> Double {
                // 1 km = 0.621371 mi
                return isMiles ? (km * 0.621371) : km
            }

            switch period { // Bucket mantığını period’a göre seçer
            case .week: // Haftalık görünüm
                // x: Günler (Pzt..Paz) // Haftanın gün etiketleri
                labels = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"] // 7 gün label dizisi

                var kcalPerDay = Array(repeating: 0.0, count: 7) // Her gün için kalori toplam dizisi
                var distPerDay = Array(repeating: 0.0, count: 7) // Her gün için mesafe (km/mi) toplam dizisi
                var durationPerDay = Array(repeating: 0, count: 7) // Her gün için süre toplam dizisi

                for run in runs { // Seçilen aralıktaki her koşuyu dolaşır
                    let weekday = cal.component(.weekday, from: run.date) // Koşunun haftanın hangi günü olduğunu alır
                    // iOS: 1=Sunday ... 7=Saturday → 0=Pzt olacak şekilde map // iOS weekday indeksini pazartesi=0 olacak şekilde dönüştürür
                    let idx = (weekday + 5) % 7   // Pazartesi=0, Pazar=6 // Gün indeksini hesaplar
                    guard idx >= 0 && idx < 7 else { continue } // Güvenlik: indeks aralık dışıysa atlar

                    kcalPerDay[idx] += run.calories // O günün kalorisini artırır
                    distPerDay[idx] += convertKmToSelectedUnit(run.distanceKm) // O günün mesafesini (km/mi) artırır
                    durationPerDay[idx] += run.durationSeconds // O günün süresini artırır
                } // for biter

                kcalValues = kcalPerDay // Haftalık kalori dizisini ana dizilere aktarır
                distValues = distPerDay // Haftalık mesafe dizisini ana dizilere aktarır
                durationValues = durationPerDay // Haftalık süre dizisini ana dizilere aktarır

            case .month: // Aylık görünüm
                // x: Her 7 güne bir bucket (1–7, 8–14 ...) // Ayı 7 günlük parçalara böler
                let dayRange = cal.range(of: .day, in: .month, for: rangeStart) ?? 1..<29 // Ayın gün aralığını alır (fallback 28 gün)
                let daysInMonth = dayRange.count // Ay içindeki gün sayısını bulur
                let bucketCount = Int(ceil(Double(daysInMonth) / 7.0)) // 7 günlük bucket sayısını hesaplar

                labels = (0..<bucketCount).map { idx in // Her bucket için label üretir
                    let startDay = idx * 7 + 1 // Bucket başlangıç günü
                    let endDay = min(startDay + 6, daysInMonth) // Bucket bitiş günü (ayın gün sayısına göre sınırlı)
                    return "\(startDay)–\(endDay)" // Örn: 1–7 gibi label döndürür
                } // map biter

                var kcalPerBucket = Array(repeating: 0.0, count: bucketCount) // Bucket bazlı kalori toplamları
                var distPerBucket = Array(repeating: 0.0, count: bucketCount) // Bucket bazlı mesafe (km/mi) toplamları
                var durationPerBucket = Array(repeating: 0, count: bucketCount) // Bucket bazlı süre toplamları

                for run in runs { // Seçilen aralıktaki her koşuyu dolaşır
                    let day = cal.component(.day, from: run.date) // Koşunun ayın kaçıncı günü olduğunu alır
                    let idx = (day - 1) / 7 // Günü 7’lik bucket indeksine çevirir
                    guard idx >= 0 && idx < bucketCount else { continue } // Güvenlik: indeks aralık dışıysa atlar

                    kcalPerBucket[idx] += run.calories // O bucket’a kalori ekler
                    distPerBucket[idx] += convertKmToSelectedUnit(run.distanceKm) // O bucket’a mesafe (km/mi) ekler
                    durationPerBucket[idx] += run.durationSeconds // O bucket’a süre ekler
                } // for biter

                kcalValues = kcalPerBucket // Aylık kalori dizisini ana dizilere aktarır
                distValues = distPerBucket // Aylık mesafe dizisini ana dizilere aktarır
                durationValues = durationPerBucket // Aylık süre dizisini ana dizilere aktarır

            case .year: // Yıllık görünüm
                // x: 4 çeyrek (quarter) // Yılı 4 çeyreğe böler
                labels = ["1.Ç","2.Ç","3.Ç","4.Ç"] // Çeyrek label’ları

                var kcalPerQuarter = Array(repeating: 0.0, count: 4) // Çeyrek bazlı kalori toplamları
                var distPerQuarter = Array(repeating: 0.0, count: 4) // Çeyrek bazlı mesafe (km/mi) toplamları
                var durationPerQuarter = Array(repeating: 0, count: 4) // Çeyrek bazlı süre toplamları

                for run in runs { // Seçilen aralıktaki her koşuyu dolaşır
                    let m = cal.component(.month, from: run.date) // Koşunun ay bilgisini alır
                    var idx = (m - 1) / 3   // 1-3 → 0, 4-6 → 1, 7-9 → 2, 10-12 → 3 // Ayı çeyreğe çevirir
                    if idx < 0 { idx = 0 } // Güvenlik: negatifse 0 yapar
                    if idx > 3 { idx = 3 } // Güvenlik: 3’ten büyükse 3 yapar

                    kcalPerQuarter[idx] += run.calories // O çeyreğe kalori ekler
                    distPerQuarter[idx] += convertKmToSelectedUnit(run.distanceKm) // O çeyreğe mesafe (km/mi) ekler
                    durationPerQuarter[idx] += run.durationSeconds // O çeyreğe süre ekler
                } // for biter

                kcalValues = kcalPerQuarter // Yıllık kalori dizisini ana dizilere aktarır
                distValues = distPerQuarter // Yıllık mesafe dizisini ana dizilere aktarır
                durationValues = durationPerQuarter // Yıllık süre dizisini ana dizilere aktarır
            } // period switch biter

            // 5) Her bucket için pace (s/km veya s/mi) // Tempo değerlerini bucket bazında hesaplar
            if !labels.isEmpty { // Bucket varsa hesaplama yapar
                pacePerBucketSec = (0..<labels.count).map { idx in // Her bucket için tempo üretir
                    let dist = idx < distValues.count ? distValues[idx] : 0 // İlgili bucket mesafe (km/mi) değeri
                    let dur = idx < durationValues.count ? durationValues[idx] : 0 // İlgili bucket süre değeri
                    guard dist > 0, dur > 0 else { return 0 } // Veri yoksa tempo 0 döndürür
                    return Double(dur) / max(dist, 0.0001) // Tempo = süre / (km veya mi)
                } // map biter
            } // if biter

            // 7) Bar chart iskeletlerini oluştur (x ekseni + bar host’lar) // Grafik view’larını yeniden kurar
            buildBarChart(in: kcalChartContainer,     chart: &kcalChart,     labels: labels) // Kalori grafiğinin iskeletini kurar
            buildBarChart(in: kmChartContainer,       chart: &kmChart,       labels: labels) // Km grafiğinin iskeletini kurar
            buildBarChart(in: durationChartContainer, chart: &durationChart, labels: labels) // Süre grafiğinin iskeletini kurar
            buildBarChart(in: paceChartContainer,     chart: &paceChart,     labels: labels) // Tempo grafiğinin iskeletini kurar

            // 8) Toplam değerler (kartların değerleri + üstte toplam) // Kartlar için toplam/ortalama değerleri hesaplar
            let totalKcal = kcalValues.reduce(0, +) // Tüm bucket kalorilerini toplayıp toplam kalori bulur
            let totalDist = distValues.reduce(0, +) // Tüm bucket mesafelerini toplayıp toplam mesafe bulur
            let totalDuration = runs.reduce(0) { $0 + $1.durationSeconds } // Tüm koşu sürelerini toplayıp toplam süre bulur
            let avgPaceSecPerUnit: Double = totalDist > 0 ? Double(totalDuration) / totalDist : 0 // Ortalama tempo (sn/km veya sn/mi)

            totalLabel.text          = "Toplam: \(Int(totalKcal.rounded())) kcal"
            kcalValueLabel.text      = "\(Int(totalKcal.rounded()))"
            kmValueLabel.text        = String(format: "%.2f %@", totalDist, distUnitSuffix) // Mesafe kartı (km/mi)
            durationValueLabel.text  = formatDuration(totalDuration)
            paceValueLabel.text      = formatPace(avgPaceSecPerUnit) // Tempo kartı (/km veya /mi)

            let runCount   = runs.count // Seçili aralıkta kaç koşu olduğunu sayar
            let activeDays = Set(runs.map { cal.startOfDay(for: $0.date) }).count // Koşu yapılan benzersiz gün sayısını hesaplar
            if runCount == 0 { // Hiç koşu yoksa
                summaryLabel.text = "Bu dönemde koşu yok" // Özet yazısını “koşu yok” yapar
            } else { // Koşu varsa
                summaryLabel.text = "Bu dönemde \(runCount) koşu • \(activeDays) aktif gün" // Koşu sayısı ve aktif gün sayısını yazar
            } // if biter

            // 9) Kalori grafiği bar yükseklikleri // Kalori bar’larını değerlere göre ölçekler
            kcalChartContainer.layoutIfNeeded() // Container ölçülerinin güncel olduğundan emin olur
            let kcalAvailable  = max(kcalChartContainer.bounds.height - 64, 60) // Bar için kullanılabilir alanı hesaplar
            let kcalMaxHeight  = min(kcalAvailable, 120) // Maks bar yüksekliğini sınırlar
            let maxKcalVal     = max(kcalValues.max() ?? 0, 0.0001) // En yüksek kalori değerini alır (0’a bölmeyi engeller)

            for i in 0..<labels.count { // Her bucket için bar’ı günceller
                let v = i < kcalValues.count ? kcalValues[i] : 0 // Bucket kalori değerini alır

                if i < kcalChart.valueLabels.count { // Değer label’ı varsa
                    kcalChart.valueLabels[i].text = v < 1 ? "0" : String(Int(v.rounded())) // Label’da gösterilecek kalori yazısını ayarlar
                } // if biter

                let ratio = CGFloat(v / maxKcalVal) // Değerin maksimuma oranını hesaplar
                let h     = max(4, ratio * kcalMaxHeight) // Orana göre bar yüksekliğini belirler (min 4)

                if i < kcalChart.heightConstraints.count { // Height constraint varsa
                    kcalChart.heightConstraints[i].constant = h // Bar yüksekliğini constraint üzerinden günceller
                } // if biter
            } // for biter

            // 10) Mesafe grafiği // Mesafe (km/mi) bar’larını değerlere göre ölçekler
            kmChartContainer.layoutIfNeeded() // Container ölçülerinin güncel olduğundan emin olur
            let kmAvailable = max(kmChartContainer.bounds.height - 64, 60) // Bar için kullanılabilir alanı hesaplar
            let kmMaxHeight = min(kmAvailable, 120) // Maks bar yüksekliğini sınırlar
            let maxDistVal  = max(distValues.max() ?? 0, 0.0001) // En yüksek mesafe değerini alır (0’a bölmeyi engeller)

            for i in 0..<labels.count { // Her bucket için bar’ı günceller
                let v = i < distValues.count ? distValues[i] : 0 // Bucket mesafe (km/mi) değerini alır

                if i < kmChart.valueLabels.count { // Değer label’ı varsa
                    if v < 0.01 { // Çok küçük değerleri 0 gibi göster
                        kmChart.valueLabels[i].text = "0"
                    } else {
                        kmChart.valueLabels[i].text = String(format: "%.2f", v)
                    }
                }

                let ratio = CGFloat(v / maxDistVal)
                let h     = max(4, ratio * kmMaxHeight)

                if i < kmChart.heightConstraints.count {
                    kmChart.heightConstraints[i].constant = h
                }
            }

            // 11) Süre grafiği // Süre bar’larını değerlere göre ölçekler
            durationChartContainer.layoutIfNeeded() // Container ölçülerinin güncel olduğundan emin olur
            let durAvailable = max(durationChartContainer.bounds.height - 64, 60) // Bar için kullanılabilir alanı hesaplar
            let durMaxHeight = min(durAvailable, 120) // Maks bar yüksekliğini sınırlar
            let maxDuration  = max(Double(durationValues.max() ?? 0), 0.0001) // En yüksek süreyi alır (0’a bölmeyi engeller)

            for i in 0..<labels.count { // Her bucket için bar’ı günceller
                let dur = i < durationValues.count ? durationValues[i] : 0 // Bucket süre değerini alır

                if dur <= 0 { // Süre yoksa
                    if i < durationChart.valueLabels.count { // Değer label’ı varsa
                        durationChart.valueLabels[i].text = "0:00" // 0 süre metni yazar
                    } // if biter
                    if i < durationChart.heightConstraints.count { // Height constraint varsa
                        durationChart.heightConstraints[i].constant = 4 // Bar’ı minimum yüksekliğe indirir
                    } // if biter
                    continue // Bu bucket için işlem yapmadan sonraki bucket’a geçer
                } // if biter

                if i < durationChart.valueLabels.count { // Değer label’ı varsa
                    durationChart.valueLabels[i].text = formatDuration(dur) // Süreyi formatlayıp label’a yazar
                } // if biter

                let ratio = CGFloat(Double(dur) / maxDuration) // Değerin maksimuma oranını hesaplar
                let h     = max(4, ratio * durMaxHeight) // Orana göre bar yüksekliğini belirler (min 4)

                if i < durationChart.heightConstraints.count { // Height constraint varsa
                    durationChart.heightConstraints[i].constant = h // Bar yüksekliğini constraint üzerinden günceller
                } // if biter
            } // for biter

            // 12) Tempo grafiği (daha hızlı tempo → daha yüksek bar) // Tempo bar’larını hız mantığıyla ölçekler
            paceChartContainer.layoutIfNeeded() // Container ölçülerinin güncel olduğundan emin olur
            let paceAvailable = max(paceChartContainer.bounds.height - 64, 60) // Bar için kullanılabilir alanı hesaplar
            let paceMaxHeight = min(paceAvailable, 120) // Maks bar yüksekliğini sınırlar

            // pace’i “speed”e çevir (1 / s/unit) → küçük değerler büyüsün // Tempo küçüldükçe (hızlandıkça) bar büyüsün diye tersine çevirir
            let paceSpeeds: [Double] = pacePerBucketSec.map { secPerUnit in
                guard secPerUnit > 0 else { return 0 }
                return 1.0 / secPerUnit
            }
            let maxSpeed = max(paceSpeeds.max() ?? 0, 0.0001)

            for i in 0..<labels.count {
                let secPerUnit = i < pacePerBucketSec.count ? pacePerBucketSec[i] : 0

                if secPerUnit <= 0 {
                    if i < paceChart.valueLabels.count {
                        paceChart.valueLabels[i].text = "0:00"
                    }
                    if i < paceChart.heightConstraints.count {
                        paceChart.heightConstraints[i].constant = 4
                    }
                    continue
                }

                if i < paceChart.valueLabels.count {
                    let m = Int(secPerUnit) / 60
                    let s = Int(secPerUnit) % 60
                    paceChart.valueLabels[i].text = String(format: "%d:%02d", m, s)
                }

                let speed = paceSpeeds[i]
                let ratio = CGFloat(speed / maxSpeed)
                let h     = max(4, ratio * paceMaxHeight)

                if i < paceChart.heightConstraints.count {
                    paceChart.heightConstraints[i].constant = h
                }
            }

        } // renderChartsAndCards biter
    } // extension biter

    // MARK: - Chart Builder
private func buildBarChart( // Grafik için bar + label kolonlarını oluşturan yardımcı fonksiyon
    in container: UIView, // Grafiğin çizileceği container view
    chart: inout StatisticsViewController.ChartState, // Bu grafiğe ait state (bar/label/constraint referansları)
    labels: [String] // X ekseninde görünecek label listesi
) { // Fonksiyon başlangıcı
        // Önce eski görünümü temizle
        container.subviews.forEach { $0.removeFromSuperview() } // Container içindeki eski alt view’ları kaldırır
        chart.stacks.removeAll() // Önceki stack referanslarını sıfırlar
        chart.bars.removeAll() // Önceki bar view referanslarını sıfırlar
        chart.valueLabels.removeAll() // Önceki değer label referanslarını sıfırlar
        chart.dayLabels.removeAll() // Önceki gün/bucket label referanslarını sıfırlar
        chart.heightConstraints.removeAll() // Önceki bar height constraint referanslarını sıfırlar

        let grid = UIStackView() // Bar kolonlarını yatay dizmek için ana grid stack’i oluşturur
        grid.axis = .horizontal // Grid’i yatay eksende düzenler
        grid.distribution = .fillEqually // Her kolonun eşit genişlikte olmasını sağlar
        grid.alignment = .bottom // Bar’ların alttan hizalanmasını sağlar
        grid.spacing = 12 // Kolonlar arası boşluğu ayarlar
        grid.isLayoutMarginsRelativeArrangement = true // Margin’leri düzenlemede kullanır
        grid.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16) // Grid’in iç boşluklarını ayarlar
        grid.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask’i kapatır

        container.addSubview(grid) // Grid stack’i container içine ekler
        NSLayoutConstraint.activate([ // Grid’in container’ı tamamen doldurması için constraint’leri aktif eder
            grid.topAnchor.constraint(equalTo: container.topAnchor), // Üst kenarı container üstüne bağlar
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor), // Sol kenarı container soluna bağlar
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor), // Sağ kenarı container sağına bağlar
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor) // Alt kenarı container altına bağlar
        ]) // Constraint bloğu biter

        for labelText in labels { // Her label için bir kolon (stack) oluşturur
            let vStack = UIStackView() // Tek bir kolonun dikey stack’ini oluşturur
            vStack.axis = .vertical // Kolon içeriğini dikey eksende düzenler
            vStack.alignment = .fill // Kolon elemanlarının genişliği doldurmasını sağlar
            vStack.spacing = 6 // Kolon içindeki elemanlar arası boşluğu ayarlar

            // Değer label (üstte)
            let valueLabel = UILabel() // Bar’ın değerini gösterecek label’ı oluşturur
            valueLabel.text = "0" // İlk değer olarak 0 yazar
            valueLabel.font = .systemFont(ofSize: 12, weight: .semibold) // Değer label fontunu ayarlar
            valueLabel.textColor = .secondaryLabel // Değer label rengini ikincil renk yapar
            valueLabel.textAlignment = .center // Metni ortalar
            valueLabel.setContentHuggingPriority(.required, for: .vertical) // Dikeyde sıkı durmasını sağlar
            valueLabel.setContentCompressionResistancePriority(.required, for: .vertical) // Dikeyde ezilmesini engeller

            // Bar host
            let barHost = UIView() // Bar’ı tutacak (yüksekliği olan) host view oluşturur
            barHost.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask’i kapatır
            barHost.backgroundColor = .clear // Host arka planını şeffaf yapar

            // Asıl bar
            let bar = UIView() // Gerçek bar view’ını oluşturur
            bar.backgroundColor = UIColor(red: 0/255.0, green: 107/255.0, blue: 255/255.0, alpha: 1.0) // Bar rengini (mavi) ayarlar
            bar.layer.cornerRadius = 6 // Bar köşelerini yuvarlar
            bar.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask’i kapatır
            barHost.addSubview(bar) // Bar’ı barHost içine ekler

            let barBottom = bar.bottomAnchor.constraint(equalTo: barHost.bottomAnchor) // Bar’ın altını host’un altına sabitler
            let barWidth  = bar.widthAnchor.constraint(equalTo: barHost.widthAnchor, multiplier: 0.6) // Bar genişliğini host genişliğinin %60’ı yapar
            let barCenter = bar.centerXAnchor.constraint(equalTo: barHost.centerXAnchor) // Bar’ı yatayda ortalar
            let barHeight = bar.heightAnchor.constraint(equalToConstant: 4) // Bar yüksekliğini başlangıçta 4 yapar (sonradan güncellenir)

            NSLayoutConstraint.activate([barBottom, barWidth, barCenter, barHeight]) // Bar constraint’lerini aktif eder
            chart.heightConstraints.append(barHeight) // Bar yüksekliğini güncelleyebilmek için constraint’i state’e kaydeder

            // Gün/bucket etiketi (altta)
            let dayLabel = UILabel() // X ekseni label’ı (gün/bucket) için label oluşturur
            dayLabel.text = labelText // Label metnini atar
            dayLabel.font = .systemFont(ofSize: 12, weight: .regular) // X label fontunu ayarlar
            dayLabel.textColor = .secondaryLabel // X label rengini ikincil renk yapar
            dayLabel.textAlignment = .center // Metni ortalar
            dayLabel.setContentHuggingPriority(.required, for: .vertical) // Dikeyde sıkı durmasını sağlar
            dayLabel.setContentCompressionResistancePriority(.required, for: .vertical) // Dikeyde ezilmesini engeller

            barHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true // Bar host’a minimum yükseklik vererek bar’a alan bırakır

            vStack.addArrangedSubview(barHost) // Kolona barHost’u ekler
            vStack.addArrangedSubview(dayLabel) // Kolona gün/bucket label’ını ekler
            vStack.addArrangedSubview(valueLabel) // Kolona değer label’ını ekler

            grid.addArrangedSubview(vStack) // Kolonu grid’e ekler

            chart.stacks.append(vStack) // Kolon stack referansını state’e kaydeder
            chart.bars.append(bar) // Bar view referansını state’e kaydeder
            chart.valueLabels.append(valueLabel) // Değer label referansını state’e kaydeder
            chart.dayLabels.append(dayLabel) // Gün/bucket label referansını state’e kaydeder
        } // labels döngüsü biter
    } // buildBarChart biter

    // MARK: - Helpers
    private func startOfWeek(for date: Date) -> Date { // Verilen tarihin haftasının pazartesi başlangıcını döndürür
        var cal = Calendar.current // Mevcut takvimi alır
        cal.firstWeekday = 2 // Haftanın ilk gününü Pazartesi (2) yapar

        var start = date // Başlangıç tarihini geçici değişkende tutar
        var interval: TimeInterval = 0 // Haftanın saniye cinsinden uzunluğunu tutacak değişken
        _ = cal.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: date) // Haftanın başlangıç tarihini hesaplar
        return start // Haftanın pazartesi başlangıcını döndürür
    } // startOfWeek biter

    private func formatDuration(_ seconds: Int) -> String { // Süreyi saniyeden okunabilir string formata çevirir
        let h = seconds / 3600 // Saat kısmını hesaplar
        let m = (seconds % 3600) / 60 // Dakika kısmını hesaplar
        let s = seconds % 60 // Saniye kısmını hesaplar

        if h > 0 { // 1 saatten büyükse
            return String(format: "%d:%02d:%02d", h, m, s) // Saatli format (h:mm:ss) döndürür
        } else { // 1 saatten küçükse
            return String(format: "%d:%02d", m, s) // Dakikalı format (m:ss) döndürür
        } // if biter
    } // formatDuration biter

    private func formatPace(_ secPerUnit: Double) -> String { // Tempo değerini (sn/km veya sn/mi) "m:ss /km|/mi" formatına çevirir
        let unitRaw = UserDefaults.standard.string(forKey: "trackly.distanceUnit") ?? "kilometers"
        let isMiles = (unitRaw == "miles")
        let suffix = isMiles ? "/mi" : "/km"

        guard secPerUnit.isFinite, secPerUnit > 0 else { return "0:00 \(suffix)" }
        let m = Int(secPerUnit) / 60
        let s = Int(secPerUnit) % 60
        return String(format: "%d:%02d %@", m, s, suffix)
    } // formatPace biter

