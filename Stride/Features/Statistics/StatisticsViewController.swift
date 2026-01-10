//
//  StatisticsViewController.swift
//  Stride
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

    // MARK: - Data + Chart
    func reloadChart() {
        // ✅ Son 12 hafta (Pzt–Paz)
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "tr_TR")
        cal.firstWeekday = 2 // Pazartesi

        let today = Date()
        let thisWeekStart = startOfWeek(for: today) // Bu haftanın Pazartesi 00:00

        // Son 12 hafta: bu hafta dahil (geri 11 hafta)
        let rangeStart = cal.date(byAdding: .weekOfYear, value: -11, to: thisWeekStart) ?? thisWeekStart
        let rangeEnd = cal.date(byAdding: .day, value: 7, to: thisWeekStart) ?? thisWeekStart

        // Üst başlık
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
        df.dateFormat = "d MMM"
        let endTitle = cal.date(byAdding: .day, value: -1, to: rangeEnd) ?? rangeEnd // Pazar
        periodLabel.text = "\(df.string(from: rangeStart)) – \(df.string(from: endTitle))"

        #if canImport(FirebaseAuth)
        guard Auth.auth().currentUser != nil else {
            renderChartsAndCards(with: [], cal: cal, rangeStart: rangeStart, rangeEnd: rangeEnd)
            return
        }

        RunFirestoreStore.shared.fetchRuns { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let runs: [Run]
                switch result {
                case .success(let fetched):
                    runs = fetched.filter { $0.date >= rangeStart && $0.date < rangeEnd }
                case .failure:
                    runs = []
                }
                self.renderChartsAndCards(with: runs, cal: cal, rangeStart: rangeStart, rangeEnd: rangeEnd)
            }
        }
        #else
        renderChartsAndCards(with: [], cal: cal, rangeStart: rangeStart, rangeEnd: rangeEnd)
        #endif
    }

    // MARK: - Render (shared)
    private func renderChartsAndCards(with runs: [Run], cal: Calendar, rangeStart: Date, rangeEnd: Date) {

        var labels: [String] = []
        var kcalValues: [Double] = []
        var distValues: [Double] = []
        var durationValues: [Int] = []
        var pacePerBucketSec: [Double] = []

        let unitRaw = UserDefaults.standard.string(forKey: "stride.distanceUnit") ?? "kilometers"
        let isMiles = (unitRaw == "miles")
        let distUnitSuffix = isMiles ? "mi" : "km"

        func convertKmToSelectedUnit(_ km: Double) -> Double {
            return isMiles ? (km * 0.621371) : km
        }

        // ✅ 12 haftalık bucket (Pzt–Paz)
        let wdf = DateFormatter()
        wdf.locale = Locale(identifier: "tr_TR")
        wdf.dateFormat = "d MMM"

        let weekStartDates: [Date] = (0..<12).compactMap { i in
            cal.date(byAdding: .weekOfYear, value: i, to: rangeStart)
        }

        labels = weekStartDates.map { wdf.string(from: $0) }

        var kcalPerWeek = Array(repeating: 0.0, count: 12)
        var distPerWeek = Array(repeating: 0.0, count: 12)
        var durationPerWeek = Array(repeating: 0, count: 12)

        for run in runs {
            let runWeekStart = startOfWeek(for: run.date)
            let diff = cal.dateComponents([.weekOfYear], from: rangeStart, to: runWeekStart).weekOfYear ?? 999
            guard diff >= 0 && diff < 12 else { continue }

            kcalPerWeek[diff] += run.calories
            distPerWeek[diff] += convertKmToSelectedUnit(run.distanceKm)
            durationPerWeek[diff] += run.durationSeconds
        }

        kcalValues = kcalPerWeek
        distValues = distPerWeek
        durationValues = durationPerWeek

        // Pace (s/km veya s/mi)
        if !labels.isEmpty {
            pacePerBucketSec = (0..<labels.count).map { idx in
                let dist = idx < distValues.count ? distValues[idx] : 0
                let dur = idx < durationValues.count ? durationValues[idx] : 0
                guard dist > 0, dur > 0 else { return 0 }
                return Double(dur) / max(dist, 0.0001)
            }
        }

        // ✅ Line chart (Past 12 weeks) — renkleri değiştirmeden
        let defaultLineColor = UIColor(red: 0/255.0, green: 107/255.0, blue: 255/255.0, alpha: 1.0)

        // Seçilen hafta aralığını üstte göstermek için (Strava gibi)
        let titleDf = DateFormatter()
        titleDf.locale = Locale(identifier: "tr_TR")
        titleDf.dateFormat = "d MMM"

        // ✅ TEK grafik: Mesafe grafiği üzerinden çiz (Strava benzeri), seçimde tüm kartları güncelle
        func weekPaceText(distance: Double, durationSec: Int) -> String {
            guard distance > 0, durationSec > 0 else { return formatPace(0) }
            return formatPace(Double(durationSec) / max(distance, 0.0001))
        }

        

        let onWeekSelected: (Int) -> Void = { [weak self] idx in
            guard let self = self else { return }
            guard idx >= 0 && idx < weekStartDates.count else { return }

            let start = weekStartDates[idx]
            let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
            self.periodLabel.text = "\(titleDf.string(from: start)) – \(titleDf.string(from: end))"
        }

        // Tooltip: tüm metrikleri aynı anda göster
        let combinedTooltip: (Int) -> String = { idx in
            let wKcal = idx < kcalValues.count ? kcalValues[idx] : 0
            let wDist = idx < distValues.count ? distValues[idx] : 0
            let wDur  = idx < durationValues.count ? durationValues[idx] : 0
            let wPace = weekPaceText(distance: wDist, durationSec: wDur)

            let distText = wDist < 0.01 ? "0 \(distUnitSuffix)" : String(format: "%.2f \(distUnitSuffix)", wDist)
            let durText  = formatDuration(wDur)
            let kcalText = wKcal < 1 ? "0 kcal" : "\(Int(wKcal.rounded())) kcal"

            return "Mesafe  \(distText)\nSüre      \(durText)\nTempo   \(wPace)\nKalori    \(kcalText)"
        }


        buildLineChart(
            in: kmChartContainer,
            values: distValues,
            weekStarts: weekStartDates,
            lineColor: defaultLineColor,
            invertY: false,
            valueFormatter: { _ in "" },
            onSelection: onWeekSelected,
            combinedFormatterForIndex: combinedTooltip
        )

        // Varsayılan: en son haftayı seç
        let lastIdx = max(0, weekStartDates.count - 1)
        onWeekSelected(lastIdx)

        let runCount   = runs.count
        let activeDays = Set(runs.map { cal.startOfDay(for: $0.date) }).count
        if runCount == 0 {
            summaryLabel.text = "Bu dönemde koşu yok"
        } else {
            summaryLabel.text = "Bu dönemde \(runCount) koşu • \(activeDays) aktif gün"
        }
    }
}


// MARK: - Line Chart Builder (Past 12 weeks)
private func buildLineChart(
    in container: UIView,
    values: [Double],
    weekStarts: [Date],
    lineColor: UIColor,
    invertY: Bool,
    valueFormatter: @escaping (Double) -> String,
    onSelection: ((Int) -> Void)?,
    combinedFormatterForIndex: ((Int) -> String)? = nil
) {
    container.subviews.forEach { $0.removeFromSuperview() }

    let chartView = LineChartView()
    chartView.translatesAutoresizingMaskIntoConstraints = false
    chartView.backgroundColor = .clear
    chartView.values = values
    chartView.weekStarts = weekStarts
    chartView.lineColor = lineColor
    chartView.invertY = invertY
    chartView.valueFormatter = valueFormatter
    chartView.onSelection = onSelection
    chartView.combinedFormatterForIndex = combinedFormatterForIndex

    container.addSubview(chartView)
    NSLayoutConstraint.activate([
        chartView.topAnchor.constraint(equalTo: container.topAnchor),
        chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    // Varsayılan seçimi en son haftaya al
    chartView.select(index: max(0, values.count - 1), animated: false)
}

private final class LineChartView: UIView {
    var values: [Double] = [] { didSet { setNeedsLayout() } }
    var weekStarts: [Date] = [] { didSet { setNeedsLayout() } }
    var lineColor: UIColor = .systemBlue { didSet { setNeedsLayout() } }
    var invertY: Bool = false { didSet { setNeedsLayout() } }
    var valueFormatter: ((Double) -> String)?
    var onSelection: ((Int) -> Void)?
    var combinedFormatterForIndex: ((Int) -> String)?

    private let gridLayer = CAShapeLayer()
    private let fillLayer = CAShapeLayer()
    private let lineLayer = CAShapeLayer()
    private let markerLayer = CAShapeLayer()

    // Strava-like selection UI
    private let tooltipPill = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let tooltipLabel = UILabel()
    private let selectedDotLayer = CAShapeLayer()

    private var selectedIndex: Int? = nil
    private var lastHapticIndex: Int? = nil
    private let haptic = UISelectionFeedbackGenerator()

    private var lastPoints: [CGPoint] = []
    private var plotRectCache: CGRect = .zero
    private var stepXCache: CGFloat = 0
    private var minXCache: CGFloat = 0

    private var dotLayers: [CAShapeLayer] = []
    private var monthLabels: [UILabel] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false

        gridLayer.strokeColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        gridLayer.lineWidth = 1
        gridLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(gridLayer)

        fillLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(fillLayer)

        lineLayer.strokeColor = lineColor.cgColor
        lineLayer.lineWidth = 3
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineJoin = .round
        lineLayer.lineCap = .round
        layer.addSublayer(lineLayer)

        markerLayer.strokeColor = UIColor.separator.withAlphaComponent(0.55).cgColor
        markerLayer.lineWidth = 2
        markerLayer.fillColor = UIColor.clear.cgColor
        markerLayer.lineDashPattern = [4, 4]
        layer.addSublayer(markerLayer)

        // Tooltip (blur pill)
        tooltipPill.layer.cornerRadius = 12
        tooltipPill.layer.masksToBounds = true
        tooltipPill.alpha = 0
        addSubview(tooltipPill)

        tooltipLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        tooltipLabel.textColor = .label
        tooltipLabel.textAlignment = .center
        tooltipLabel.numberOfLines = 0
        tooltipLabel.translatesAutoresizingMaskIntoConstraints = false
        tooltipPill.contentView.addSubview(tooltipLabel)

        NSLayoutConstraint.activate([
            tooltipLabel.leadingAnchor.constraint(equalTo: tooltipPill.contentView.leadingAnchor, constant: 12),
            tooltipLabel.trailingAnchor.constraint(equalTo: tooltipPill.contentView.trailingAnchor, constant: -12),
            tooltipLabel.topAnchor.constraint(equalTo: tooltipPill.contentView.topAnchor, constant: 8),
            tooltipLabel.bottomAnchor.constraint(equalTo: tooltipPill.contentView.bottomAnchor, constant: -8)
        ])

        // Selected dot ring
        selectedDotLayer.fillColor = UIColor.systemBackground.withAlphaComponent(0.9).cgColor
        selectedDotLayer.strokeColor = lineColor.cgColor
        selectedDotLayer.lineWidth = 5
        layer.addSublayer(selectedDotLayer)

        haptic.prepare()

        // ScrollView ile daha akıcı: long-press (0s) ile sürükleme
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        press.minimumPressDuration = 0
        press.allowableMovement = 60
        addGestureRecognizer(press)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func select(index: Int, animated: Bool) {
        let maxIdx = max(0, values.count - 1)
        let clamped = max(0, min(maxIdx, index))
        selectedIndex = clamped
        applySelectionUI(animated: animated)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        dotLayers.forEach { $0.removeFromSuperlayer() }
        dotLayers.removeAll()
        monthLabels.forEach { $0.removeFromSuperview() }
        monthLabels.removeAll()

        // Daha kompakt, Strava benzeri alan
        let left: CGFloat = 14
        let right: CGFloat = 14
        let top: CGFloat = 14
        let bottom: CGFloat = 34

        let plotRect = CGRect(
            x: left,
            y: top,
            width: max(1, bounds.width - left - right),
            height: max(1, bounds.height - top - bottom)
        )
        plotRectCache = plotRect

        // Grid (3 çizgi)
        let gridPath = UIBezierPath()
        let y0 = plotRect.maxY
        let y1 = plotRect.minY + plotRect.height * 0.52
        let y2 = plotRect.minY
        [y2, y1, y0].forEach { y in
            gridPath.move(to: CGPoint(x: plotRect.minX, y: y))
            gridPath.addLine(to: CGPoint(x: plotRect.maxX, y: y))
        }
        gridLayer.path = gridPath.cgPath

        let safeValues = values
        let maxVal = max(safeValues.max() ?? 0, 0.0001)

        let n = max(safeValues.count, 2)
        let stepX: CGFloat = n > 1 ? (plotRect.width / CGFloat(n - 1)) : 0
        stepXCache = stepX
        minXCache = plotRect.minX

        func point(at idx: Int) -> CGPoint {
            let v = idx < safeValues.count ? safeValues[idx] : 0

            // Normal: büyük değer yukarı
            // invertY: küçük değer yukarı (tempo gibi)
            let normalized: CGFloat
            if invertY {
                // 0 olanları en alta sabitle
                guard v > 0 else { normalized = 0; return CGPoint(x: plotRect.minX + CGFloat(idx) * stepX, y: plotRect.maxY) }
                let minVal = max((safeValues.filter { $0 > 0 }.min() ?? v), 0.0001)
                let maxValLocal = max((safeValues.max() ?? v), minVal + 0.0001)
                let inv = (maxValLocal - v) / (maxValLocal - minVal)
                normalized = CGFloat(inv)
            } else {
                normalized = CGFloat(v / maxVal)
            }

            let x = plotRect.minX + CGFloat(idx) * stepX
            let y = plotRect.maxY - normalized * plotRect.height
            return CGPoint(x: x, y: y)
        }

        lastPoints = (0..<safeValues.count).map { point(at: $0) }

        // Line
        let linePath = UIBezierPath()
        if !safeValues.isEmpty {
            linePath.move(to: point(at: 0))
            for i in 1..<safeValues.count {
                linePath.addLine(to: point(at: i))
            }
        }

        // Fill
        let fillPath = UIBezierPath()
        if !safeValues.isEmpty {
            fillPath.move(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
            fillPath.addLine(to: point(at: 0))
            for i in 1..<safeValues.count {
                fillPath.addLine(to: point(at: i))
            }
            fillPath.addLine(to: CGPoint(x: plotRect.minX + CGFloat(safeValues.count - 1) * stepX, y: plotRect.maxY))
            fillPath.close()
        }

        lineLayer.strokeColor = lineColor.cgColor
        selectedDotLayer.strokeColor = lineColor.cgColor
        lineLayer.path = linePath.cgPath

        fillLayer.fillColor = lineColor.withAlphaComponent(0.18).cgColor
        fillLayer.path = fillPath.cgPath

        // Dots
        for i in 0..<safeValues.count {
            let p = point(at: i)
            let dot = CAShapeLayer()
            let r: CGFloat = 5
            dot.path = UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)).cgPath
            dot.fillColor = UIColor.systemBackground.withAlphaComponent(0.75).cgColor
            dot.strokeColor = lineColor.cgColor
            dot.lineWidth = 3
            layer.addSublayer(dot)
            dotLayers.append(dot)
        }

        // Month labels (NOV/DEC/JAN)
        guard !weekStarts.isEmpty else { applySelectionUI(animated: false); return }
        let mdf = DateFormatter()
        mdf.locale = Locale(identifier: "en_US_POSIX")
        mdf.dateFormat = "MMM"

        var lastMonth: Int? = nil
        for i in 0..<min(weekStarts.count, safeValues.count) {
            let m = Calendar(identifier: .gregorian).component(.month, from: weekStarts[i])
            if lastMonth == nil || lastMonth != m {
                lastMonth = m
                let label = UILabel()
                label.font = .systemFont(ofSize: 14, weight: .semibold)
                label.textColor = .secondaryLabel
                label.textAlignment = .center
                label.text = mdf.string(from: weekStarts[i]).uppercased()
                addSubview(label)

                let x = plotRect.minX + CGFloat(i) * stepX
                label.sizeToFit()
                label.center = CGPoint(x: x, y: plotRect.maxY + 18)
                monthLabels.append(label)
            }
        }

        applySelectionUI(animated: false)
    }

    @objc private func handlePan(_ g: UIGestureRecognizer) {
        guard stepXCache > 0, !lastPoints.isEmpty else { return }
        let loc = g.location(in: self)

        // Sadece plot alanında yakala
        if !plotRectCache.contains(loc) { return }

        // Direkt hesap: index ≈ (x - minX) / stepX
        let raw = (loc.x - minXCache) / stepXCache
        let idx = Int(round(raw))
        let clamped = max(0, min(lastPoints.count - 1, idx))

        if selectedIndex != clamped {
            selectedIndex = clamped
            applySelectionUI(animated: false)
        }
    }

    private func applySelectionUI(animated: Bool) {
        guard let idx = selectedIndex, idx >= 0, idx < lastPoints.count else {
            markerLayer.path = nil
            selectedDotLayer.path = nil
            lastHapticIndex = nil
            if animated {
                UIView.animate(withDuration: 0.15) { self.tooltipPill.alpha = 0 }
            } else {
                tooltipPill.alpha = 0
            }
            return
        }

        let p = lastPoints[idx]

        if lastHapticIndex != idx {
            haptic.selectionChanged()
            haptic.prepare()
            lastHapticIndex = idx
        }

        // Dikey marker çizgisi
        let m = UIBezierPath()
        m.move(to: CGPoint(x: p.x, y: plotRectCache.minY))
        m.addLine(to: CGPoint(x: p.x, y: plotRectCache.maxY))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        markerLayer.path = m.cgPath
        CATransaction.commit()

        // Tooltip metni
        let v = idx < values.count ? values[idx] : 0
        if let combined = combinedFormatterForIndex {
            tooltipLabel.text = combined(idx)
        } else {
            let text = valueFormatter?(v) ?? String(format: "%.2f", v)
            tooltipLabel.text = text
        }

        tooltipPill.setNeedsLayout()
        tooltipPill.layoutIfNeeded()
        let size = tooltipPill.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)

        let w = max(60, min(size.width, plotRectCache.width))
        let h = size.height

        var tx = p.x - w / 2
        tx = max(plotRectCache.minX, min(plotRectCache.maxX - w, tx))
        let ty = plotRectCache.minY + 6

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tooltipPill.frame = CGRect(x: tx, y: ty, width: w, height: h)
        CATransaction.commit()

        if animated {
            UIView.animate(withDuration: 0.12) { self.tooltipPill.alpha = 1 }
        } else {
            tooltipPill.alpha = 1
        }

        // Seçili nokta vurgusu
        let rOuter: CGFloat = 9
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectedDotLayer.path = UIBezierPath(
            ovalIn: CGRect(x: p.x - rOuter, y: p.y - rOuter, width: rOuter * 2, height: rOuter * 2)
        ).cgPath
        CATransaction.commit()

        onSelection?(idx)
    }
}

// MARK: - Helpers
private func startOfWeek(for date: Date) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.locale = Locale(identifier: "tr_TR")
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

private func formatPace(_ secPerUnit: Double) -> String {
    let unitRaw = UserDefaults.standard.string(forKey: "stride.distanceUnit") ?? "kilometers"
    let isMiles = (unitRaw == "miles")
    let suffix = isMiles ? "/mi" : "/km"

    guard secPerUnit.isFinite, secPerUnit > 0 else { return "0:00 \(suffix)" }
    let m = Int(secPerUnit) / 60
    let s = Int(secPerUnit) % 60
    return String(format: "%d:%02d %@", m, s, suffix)
}
