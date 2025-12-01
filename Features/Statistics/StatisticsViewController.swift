import UIKit

extension StatisticsViewController {

    // MARK: - Data + Chart
    func reloadChart() {
        let cal = Calendar.current
        let today = Date()

        var rangeStart: Date
        var rangeEnd: Date

        // 1) Seçilen döneme göre tarih aralığı (week / month / year)
        switch period {
        case .week:
            let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: today) ?? today
            rangeStart = startOfWeek(for: base)
            rangeEnd = cal.date(byAdding: .day, value: 7, to: rangeStart) ?? rangeStart

        case .month:
            let base = cal.date(byAdding: .month, value: monthOffset, to: today) ?? today
            let comps = cal.dateComponents([.year, .month], from: base)
            rangeStart = cal.date(from: comps) ?? base
            rangeEnd = cal.date(byAdding: .month, value: 1, to: rangeStart) ?? rangeStart

        case .year:
            let base = cal.date(byAdding: .year, value: yearOffset, to: today) ?? today
            let comps = cal.dateComponents([.year], from: base)
            rangeStart = cal.date(from: comps) ?? base
            rangeEnd = cal.date(byAdding: .year, value: 1, to: rangeStart) ?? rangeStart
        }

        // 2) Üstteki tarih başlığı (Hafta / Ay / Yıl etiketi)
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")

        switch period {
        case .week:
            df.dateFormat = "d MMM"
            let endTitle = cal.date(byAdding: .day, value: 6, to: rangeStart) ?? rangeStart
            periodLabel.text = "\(df.string(from: rangeStart)) – \(df.string(from: endTitle))"

        case .month:
            df.dateFormat = "LLLL yyyy"
            periodLabel.text = df.string(from: rangeStart)

        case .year:
            df.dateFormat = "yyyy"
            periodLabel.text = df.string(from: rangeStart)
        }

        // 3) Bu aralıktaki tüm koşular
        let runs = RunStore.shared.runs.filter { $0.date >= rangeStart && $0.date < rangeEnd }

        // 4) Grafik bucket dizileri (x ekseni label + y değerleri)
        var labels: [String] = []
        var kcalValues: [Double] = []
        var kmValues: [Double] = []
        var durationValues: [Int] = []
        var pacePerBucketSec: [Double] = []   // her bucket için ortalama pace (s/km)
        var stepsValues: [Int] = []           // her bucket için adım sayısı

        switch period {
        case .week:
            // x: Günler (Pzt..Paz)
            labels = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

            var kcalPerDay = Array(repeating: 0.0, count: 7)
            var kmPerDay = Array(repeating: 0.0, count: 7)
            var durationPerDay = Array(repeating: 0, count: 7)

            for run in runs {
                let weekday = cal.component(.weekday, from: run.date)
                // iOS: 1=Sunday ... 7=Saturday → 0=Pzt olacak şekilde map
                let idx = (weekday + 5) % 7   // Pazartesi=0, Pazar=6
                guard idx >= 0 && idx < 7 else { continue }

                kcalPerDay[idx] += run.calories
                kmPerDay[idx] += run.distanceKm
                durationPerDay[idx] += run.durationSeconds
            }

            kcalValues = kcalPerDay
            kmValues = kmPerDay
            durationValues = durationPerDay

        case .month:
            // x: Her 7 güne bir bucket (1–7, 8–14 ...)
            let dayRange = cal.range(of: .day, in: .month, for: rangeStart) ?? 1..<29
            let daysInMonth = dayRange.count
            let bucketCount = Int(ceil(Double(daysInMonth) / 7.0))

            labels = (0..<bucketCount).map { idx in
                let startDay = idx * 7 + 1
                let endDay = min(startDay + 6, daysInMonth)
                return "\(startDay)–\(endDay)"
            }

            var kcalPerBucket = Array(repeating: 0.0, count: bucketCount)
            var kmPerBucket = Array(repeating: 0.0, count: bucketCount)
            var durationPerBucket = Array(repeating: 0, count: bucketCount)

            for run in runs {
                let day = cal.component(.day, from: run.date)
                let idx = (day - 1) / 7
                guard idx >= 0 && idx < bucketCount else { continue }

                kcalPerBucket[idx] += run.calories
                kmPerBucket[idx] += run.distanceKm
                durationPerBucket[idx] += run.durationSeconds
            }

            kcalValues = kcalPerBucket
            kmValues = kmPerBucket
            durationValues = durationPerBucket

        case .year:
            // x: 4 çeyrek (quarter)
            labels = ["1.Ç","2.Ç","3.Ç","4.Ç"]

            var kcalPerQuarter = Array(repeating: 0.0, count: 4)
            var kmPerQuarter = Array(repeating: 0.0, count: 4)
            var durationPerQuarter = Array(repeating: 0, count: 4)

            for run in runs {
                let m = cal.component(.month, from: run.date)
                var idx = (m - 1) / 3   // 1-3 → 0, 4-6 → 1, 7-9 → 2, 10-12 → 3
                if idx < 0 { idx = 0 }
                if idx > 3 { idx = 3 }

                kcalPerQuarter[idx] += run.calories
                kmPerQuarter[idx] += run.distanceKm
                durationPerQuarter[idx] += run.durationSeconds
            }

            kcalValues = kcalPerQuarter
            kmValues = kmPerQuarter
            durationValues = durationPerQuarter
        }

        // 5) Her bucket için pace (s/km)
        if !labels.isEmpty {
            pacePerBucketSec = (0..<labels.count).map { idx in
                let km = idx < kmValues.count ? kmValues[idx] : 0
                let dur = idx < durationValues.count ? durationValues[idx] : 0
                guard km > 0, dur > 0 else { return 0 }
                return Double(dur) / max(km, 0.0001)
            }
        }

        // 6) Adım sayısı (her bucket için) ~1300 adım / km
        let stepsPerKm = 1300.0
        stepsValues = kmValues.map { km in
            Int((km * stepsPerKm).rounded())
        }

        // 7) Bar chart iskeletlerini oluştur (x ekseni + bar host’lar)
        buildBarChart(in: kcalChartContainer,     chart: &kcalChart,     labels: labels)
        buildBarChart(in: kmChartContainer,       chart: &kmChart,       labels: labels)
        buildBarChart(in: durationChartContainer, chart: &durationChart, labels: labels)
        buildBarChart(in: paceChartContainer,     chart: &paceChart,     labels: labels)
        buildBarChart(in: stepsChartContainer,    chart: &stepsChart,    labels: labels)

        // 8) Toplam değerler (kartların değerleri + üstte toplam)
        let totalKcal = kcalValues.reduce(0, +)
        let totalKm = kmValues.reduce(0, +)
        let totalDuration = runs.reduce(0) { $0 + $1.durationSeconds }
        let avgPaceSecPerKm: Double = totalKm > 0 ? Double(totalDuration) / totalKm : 0
        let totalSteps = Int((totalKm * stepsPerKm).rounded())

        totalLabel.text          = "Toplam: \(Int(totalKcal.rounded())) kcal"
        kcalValueLabel.text      = "\(Int(totalKcal.rounded()))"
        kmValueLabel.text        = String(format: "%.2f km", totalKm)
        durationValueLabel.text  = formatDuration(totalDuration)
        paceValueLabel.text      = formatPace(avgPaceSecPerKm)
        stepsValueLabel.text     = "\(totalSteps)"

        let runCount   = runs.count
        let activeDays = Set(runs.map { cal.startOfDay(for: $0.date) }).count
        if runCount == 0 {
            summaryLabel.text = "Bu dönemde koşu yok"
        } else {
            summaryLabel.text = "Bu dönemde \(runCount) koşu • \(activeDays) aktif gün"
        }

        // 9) Kalori grafiği bar yükseklikleri
        kcalChartContainer.layoutIfNeeded()
        let kcalAvailable  = max(kcalChartContainer.bounds.height - 64, 60)
        let kcalMaxHeight  = min(kcalAvailable, 120)
        let maxKcalVal     = max(kcalValues.max() ?? 0, 0.0001)

        for i in 0..<labels.count {
            let v = i < kcalValues.count ? kcalValues[i] : 0

            if i < kcalChart.valueLabels.count {
                kcalChart.valueLabels[i].text = v < 1 ? "0" : String(Int(v.rounded()))
            }

            let ratio = CGFloat(v / maxKcalVal)
            let h     = max(4, ratio * kcalMaxHeight)

            if i < kcalChart.heightConstraints.count {
                kcalChart.heightConstraints[i].constant = h
            }
        }

        // 10) Mesafe grafiği
        kmChartContainer.layoutIfNeeded()
        let kmAvailable = max(kmChartContainer.bounds.height - 64, 60)
        let kmMaxHeight = min(kmAvailable, 120)
        let maxKmVal    = max(kmValues.max() ?? 0, 0.0001)

        for i in 0..<labels.count {
            let v = i < kmValues.count ? kmValues[i] : 0

            if i < kmChart.valueLabels.count {
                if v < 0.01 {
                    kmChart.valueLabels[i].text = "0"
                } else {
                    kmChart.valueLabels[i].text = String(format: "%.2f", v)
                }
            }

            let ratio = CGFloat(v / maxKmVal)
            let h     = max(4, ratio * kmMaxHeight)

            if i < kmChart.heightConstraints.count {
                kmChart.heightConstraints[i].constant = h
            }
        }

        // 11) Süre grafiği
        durationChartContainer.layoutIfNeeded()
        let durAvailable = max(durationChartContainer.bounds.height - 64, 60)
        let durMaxHeight = min(durAvailable, 120)
        let maxDuration  = max(Double(durationValues.max() ?? 0), 0.0001)

        for i in 0..<labels.count {
            let dur = i < durationValues.count ? durationValues[i] : 0

            if dur <= 0 {
                if i < durationChart.valueLabels.count {
                    durationChart.valueLabels[i].text = "0:00"
                }
                if i < durationChart.heightConstraints.count {
                    durationChart.heightConstraints[i].constant = 4
                }
                continue
            }

            if i < durationChart.valueLabels.count {
                durationChart.valueLabels[i].text = formatDuration(dur)
            }

            let ratio = CGFloat(Double(dur) / maxDuration)
            let h     = max(4, ratio * durMaxHeight)

            if i < durationChart.heightConstraints.count {
                durationChart.heightConstraints[i].constant = h
            }
        }

        // 12) Tempo grafiği (daha hızlı tempo → daha yüksek bar)
        paceChartContainer.layoutIfNeeded()
        let paceAvailable = max(paceChartContainer.bounds.height - 64, 60)
        let paceMaxHeight = min(paceAvailable, 120)

        // pace’i “speed”e çevir (1 / s/km) → küçük değerler büyüsün
        let paceSpeeds: [Double] = pacePerBucketSec.map { secPerKm in
            guard secPerKm > 0 else { return 0 }
            return 1.0 / secPerKm
        }
        let maxSpeed = max(paceSpeeds.max() ?? 0, 0.0001)

        for i in 0..<labels.count {
            let secPerKm = i < pacePerBucketSec.count ? pacePerBucketSec[i] : 0

            if secPerKm <= 0 {
                if i < paceChart.valueLabels.count {
                    paceChart.valueLabels[i].text = "0:00"
                }
                if i < paceChart.heightConstraints.count {
                    paceChart.heightConstraints[i].constant = 4
                }
                continue
            }

            if i < paceChart.valueLabels.count {
                let m = Int(secPerKm) / 60
                let s = Int(secPerKm) % 60
                paceChart.valueLabels[i].text = String(format: "%d:%02d", m, s)
            }

            let speed = paceSpeeds[i]
            let ratio = CGFloat(speed / maxSpeed)
            let h     = max(4, ratio * paceMaxHeight)

            if i < paceChart.heightConstraints.count {
                paceChart.heightConstraints[i].constant = h
            }
        }

        // 13) Adım grafiği
        stepsChartContainer.layoutIfNeeded()
        let stepsAvailable = max(stepsChartContainer.bounds.height - 64, 60)
        let stepsMaxHeight = min(stepsAvailable, 120)
        let maxStepsVal    = max(Double(stepsValues.max() ?? 0), 0.0001)

        for i in 0..<labels.count {
            let steps = i < stepsValues.count ? stepsValues[i] : 0

            if i < stepsChart.valueLabels.count {
                stepsChart.valueLabels[i].text = steps > 0 ? "\(steps)" : "0"
            }

            let ratio = CGFloat(Double(steps) / maxStepsVal)
            let h     = max(4, ratio * stepsMaxHeight)

            if i < stepsChart.heightConstraints.count {
                stepsChart.heightConstraints[i].constant = h
            }
        }
    }

    // MARK: - Chart Builder
    private func buildBarChart(
        in container: UIView,
        chart: inout ChartState,
        labels: [String]
    ) {
        // Önce eski görünümü temizle
        container.subviews.forEach { $0.removeFromSuperview() }
        chart.stacks.removeAll()
        chart.bars.removeAll()
        chart.valueLabels.removeAll()
        chart.dayLabels.removeAll()
        chart.heightConstraints.removeAll()

        let grid = UIStackView()
        grid.axis = .horizontal
        grid.distribution = .fillEqually
        grid.alignment = .bottom
        grid.spacing = 12
        grid.isLayoutMarginsRelativeArrangement = true
        grid.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        grid.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        for labelText in labels {
            let vStack = UIStackView()
            vStack.axis = .vertical
            vStack.alignment = .fill
            vStack.spacing = 6

            // Değer label (üstte)
            let valueLabel = UILabel()
            valueLabel.text = "0"
            valueLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            valueLabel.textColor = .secondaryLabel
            valueLabel.textAlignment = .center

            // Bar host
            let barHost = UIView()
            barHost.translatesAutoresizingMaskIntoConstraints = false
            barHost.backgroundColor = .clear

            // Asıl bar
            let bar = UIView()
            bar.backgroundColor = UIColor(red: 0/255.0, green: 107/255.0, blue: 255/255.0, alpha: 1.0)
            bar.layer.cornerRadius = 6
            bar.translatesAutoresizingMaskIntoConstraints = false
            barHost.addSubview(bar)

            let barBottom = bar.bottomAnchor.constraint(equalTo: barHost.bottomAnchor)
            let barWidth  = bar.widthAnchor.constraint(equalTo: barHost.widthAnchor, multiplier: 0.6)
            let barCenter = bar.centerXAnchor.constraint(equalTo: barHost.centerXAnchor)
            let barHeight = bar.heightAnchor.constraint(equalToConstant: 4)

            NSLayoutConstraint.activate([barBottom, barWidth, barCenter, barHeight])
            chart.heightConstraints.append(barHeight)

            // Gün/bucket etiketi (altta)
            let dayLabel = UILabel()
            dayLabel.text = labelText
            dayLabel.font = .systemFont(ofSize: 12, weight: .regular)
            dayLabel.textColor = .secondaryLabel
            dayLabel.textAlignment = .center

            barHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true

            vStack.addArrangedSubview(barHost)
            vStack.addArrangedSubview(dayLabel)
            vStack.addArrangedSubview(valueLabel)

            grid.addArrangedSubview(vStack)

            chart.stacks.append(vStack)
            chart.bars.append(bar)
            chart.valueLabels.append(valueLabel)
            chart.dayLabels.append(dayLabel)
        }
    }

    // MARK: - Helpers
    private func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Pazartesi

        var start = date
        var interval: TimeInterval = 0
        _ = cal.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: date)
        return start
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    private func formatPace(_ secPerKm: Double) -> String {
        guard secPerKm.isFinite, secPerKm > 0 else { return "0:00 /km" }
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }
}
