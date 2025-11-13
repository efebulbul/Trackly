import UIKit

// MARK: - StatisticsViewController
final class StatisticsViewController: UIViewController {

    // MARK: UI
    private let header = UIStackView()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let weekLabel = UILabel()
    
    private let chartContainer = UIView()
    private let totalLabel = UILabel()
    private let statsRow = UIStackView()
    private let kcalCard = UIView()
    private let kmCard = UIView()
    private let kcalValueLabel = UILabel()
    private let kmValueLabel = UILabel()
    
    private var barStacks: [UIStackView] = []
    private var barViews: [UIView] = []
    private var valueLabels: [UILabel] = []
    private var dayLabels: [UILabel] = []
    private var barHeightConstraints: [NSLayoutConstraint] = []

    // MARK: State
    private var weekOffset: Int = 0  // 0: bu hafta, -1: geçen hafta, +1: sonraki hafta

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        applyBrandTitle() // ✅ Trackly (ly mavi)
        title = "İstatistikler"
        view.backgroundColor = .systemBackground
        setupUI()
        reloadChart()
    }

    // MARK: UI Setup
    private func setupUI() {
        // Header (prev | label | next) centered horizontally
        header.axis = .horizontal
        header.alignment = .center
        header.distribution = .equalCentering
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false

        prevButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        prevButton.addTarget(self, action: #selector(prevWeek), for: .touchUpInside)

        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextWeek), for: .touchUpInside)

        weekLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        weekLabel.textColor = .label
        weekLabel.textAlignment = .center
        weekLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        header.addArrangedSubview(prevButton)
        header.addArrangedSubview(weekLabel)
        header.addArrangedSubview(nextButton)
        prevButton.setContentHuggingPriority(.required, for: .horizontal)
        nextButton.setContentHuggingPriority(.required, for: .horizontal)
        prevButton.widthAnchor.constraint(equalTo: nextButton.widthAnchor).isActive = true
        weekLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Chart container
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.backgroundColor = .secondarySystemBackground
        chartContainer.layer.cornerRadius = 16

        totalLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        totalLabel.textColor = .label
        totalLabel.textAlignment = .left
        totalLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(totalLabel)
        view.addSubview(chartContainer)
        view.addSubview(statsRow)

        NSLayoutConstraint.activate([
            // Header pinned to top
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
    
            // Total label just under header
            totalLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            totalLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            totalLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
    
            // Chart as a rounded panel
            chartContainer.topAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: 8),
            chartContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            chartContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            chartContainer.bottomAnchor.constraint(equalTo: statsRow.topAnchor, constant: -12),
    
            // Stats row below chart
            statsRow.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: 12),
            statsRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statsRow.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])

        statsRow.axis = .horizontal
        statsRow.alignment = .fill
        statsRow.distribution = .fillEqually
        statsRow.spacing = 12
        statsRow.translatesAutoresizingMaskIntoConstraints = false
    
        func styleCard(_ v: UIView) {
            v.backgroundColor = .secondarySystemBackground
            v.layer.cornerRadius = 14
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        styleCard(kcalCard)
        styleCard(kmCard)
    
        // Kcal card
        let kcalTitle = UILabel()
        kcalTitle.text = "Kalori"
        kcalTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        kcalTitle.textColor = .secondaryLabel
        kcalValueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        kcalValueLabel.textColor = .label
        let kcalStack = UIStackView(arrangedSubviews: [kcalTitle, kcalValueLabel])
        kcalStack.axis = .vertical
        kcalStack.spacing = 4
        kcalStack.isLayoutMarginsRelativeArrangement = true
        kcalStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        kcalStack.translatesAutoresizingMaskIntoConstraints = false
        kcalCard.addSubview(kcalStack)
        NSLayoutConstraint.activate([
            kcalStack.topAnchor.constraint(equalTo: kcalCard.topAnchor),
            kcalStack.leadingAnchor.constraint(equalTo: kcalCard.leadingAnchor),
            kcalStack.trailingAnchor.constraint(equalTo: kcalCard.trailingAnchor),
            kcalStack.bottomAnchor.constraint(equalTo: kcalCard.bottomAnchor),
            kcalCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])
    
        // Km card
        let kmTitle = UILabel()
        kmTitle.text = "Mesafe"
        kmTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        kmTitle.textColor = .secondaryLabel
        kmValueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        kmValueLabel.textColor = .label
        let kmStack = UIStackView(arrangedSubviews: [kmTitle, kmValueLabel])
        kmStack.axis = .vertical
        kmStack.spacing = 4
        kmStack.isLayoutMarginsRelativeArrangement = true
        kmStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        kmStack.translatesAutoresizingMaskIntoConstraints = false
        kmCard.addSubview(kmStack)
        NSLayoutConstraint.activate([
            kmStack.topAnchor.constraint(equalTo: kmCard.topAnchor),
            kmStack.leadingAnchor.constraint(equalTo: kmCard.leadingAnchor),
            kmStack.trailingAnchor.constraint(equalTo: kmCard.trailingAnchor),
            kmStack.bottomAnchor.constraint(equalTo: kmCard.bottomAnchor),
            kmCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])
    
        statsRow.addArrangedSubview(kcalCard)
        statsRow.addArrangedSubview(kmCard)
        
        buildBars()
    }

    private func buildBars() {
        // Temizle
        chartContainer.subviews.forEach { $0.removeFromSuperview() }
        barStacks.removeAll(); barViews.removeAll()
        valueLabels.removeAll(); dayLabels.removeAll()
        barHeightConstraints.removeAll()

        // 7 eşit sütun
        let grid = UIStackView()
        grid.axis = .horizontal
        grid.distribution = .fillEqually
        grid.alignment = .bottom
        grid.spacing = 12
        grid.isLayoutMarginsRelativeArrangement = true
        grid.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        grid.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: chartContainer.topAnchor),
            grid.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor)
        ])

        let dayShorts = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

        for i in 0..<7 {
            let vStack = UIStackView()
            vStack.axis = .vertical
            vStack.alignment = .fill
            vStack.spacing = 6

            // Değer etiketi (bar üstü)
            let value = UILabel()
            value.text = "0"
            value.font = .systemFont(ofSize: 12, weight: .semibold)
            value.textColor = .secondaryLabel
            value.textAlignment = .center

            // Bar
            let barHost = UIView()
            barHost.translatesAutoresizingMaskIntoConstraints = false
            barHost.backgroundColor = .clear

            let bar = UIView()
            // UIColor(hex:) projenizde zaten var; yoksa systemBlue kullanabilirsiniz.
            bar.backgroundColor = UIColor(hex: "#006BFF")
            bar.layer.cornerRadius = 6
            bar.translatesAutoresizingMaskIntoConstraints = false
            barHost.addSubview(bar)

            // Başlangıçta küçük, sonra reloadChart'ta güncellenecek
            let barBottom = bar.bottomAnchor.constraint(equalTo: barHost.bottomAnchor)
            let barWidth  = bar.widthAnchor.constraint(equalTo: barHost.widthAnchor, multiplier: 0.6)
            let barCenter = bar.centerXAnchor.constraint(equalTo: barHost.centerXAnchor)
            let barHeight = bar.heightAnchor.constraint(equalToConstant: 4)
            NSLayoutConstraint.activate([barBottom, barWidth, barCenter, barHeight])
            barHeightConstraints.append(barHeight)

            // Gün etiketi
            let day = UILabel()
            day.text = dayShorts[i]
            day.font = .systemFont(ofSize: 12, weight: .regular)
            day.textColor = .secondaryLabel
            day.textAlignment = .center

            // Host min yükseklik
            barHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true

            vStack.addArrangedSubview(barHost)
            vStack.addArrangedSubview(day)
            vStack.addArrangedSubview(value)
            grid.addArrangedSubview(vStack)

            barStacks.append(vStack)
            barViews.append(bar)
            valueLabels.append(value)
            dayLabels.append(day)
        }
    }

    // MARK: Data + Chart
    private struct DayStat {
        let date: Date
        let kcal: Double
        let km: Double
    }

    @objc private func metricChanged() { reloadChart() }
    @objc private func prevWeek() { weekOffset -= 1; reloadChart() }
    @objc private func nextWeek() { weekOffset += 1; reloadChart() }

    private func reloadChart() {
        let cal = Calendar.current
        let today = Date()
        let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: today)!
        let startOfWeek = self.startOfWeek(for: base)
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfWeek)!

        // Başlık: "4 – 10 Kas"
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
        df.dateFormat = "d MMM"
        let titleText = "\(df.string(from: startOfWeek)) – \(df.string(from: cal.date(byAdding: .day, value: 6, to: startOfWeek)!))"
        weekLabel.text = titleText

        // 7 günlük bucket (Pzt..Paz)
        var buckets: [DayStat] = []
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: i, to: startOfWeek)!
            buckets.append(DayStat(date: d, kcal: 0, km: 0))
        }

        // O haftanın koşularını grupla
        let runs = RunStore.shared.runs.filter { $0.date >= startOfWeek && $0.date < endOfWeek }
        for run in runs {
            let weekday = cal.component(.weekday, from: run.date) // 1=Sun…7=Sat
            let idx = ((weekday + 5) % 7) // Pazartesi=0, ... Pazar=6
            guard idx >= 0 && idx < 7 else { continue }
            let old = buckets[idx]
            buckets[idx] = DayStat(date: old.date,
                                   kcal: old.kcal + run.calories,
                                   km:   old.km   + run.distanceKm)
        }

        // Values for bars = calories per day
        let values = buckets.map { $0.kcal }
        let maxVal = max(values.max() ?? 0, 0.0001)
    
        // Totals (cards + small total label)
        let totalKcal = values.reduce(0, +)
        let totalKm = runs.reduce(0.0) { $0 + $1.distanceKm }
        totalLabel.text = "Toplam: \(Int(totalKcal.rounded())) kcal"
        kcalValueLabel.text = "\(Int(totalKcal.rounded()))"
        kmValueLabel.text = String(format: "%.2f km", totalKm)

        chartContainer.layoutIfNeeded()
        let available = max(chartContainer.bounds.height - 64, 60) // padding + label için boşluk
        let maxBarHeight = min(available, 120)

        // Barları güncelle
        for i in 0..<7 {
            let v = values[i]
            valueLabels[i].text = v < 1 ? "0" : String(Int(v.rounded()))

            let ratio = CGFloat(v / maxVal)
            let h = max(4, ratio * maxBarHeight)

            let bar = barViews[i]
            if i < barHeightConstraints.count {
                barHeightConstraints[i].constant = h
            }
        }
    }

    private func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Pazartesi
        var start = date
        var interval: TimeInterval = 0
        _ = cal.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: date)
        return start
    }

    // MARK: - Brand Title
    private func applyBrandTitle() {
        let label = UILabel()
        let title = NSMutableAttributedString(
            string: "Track",
            attributes: [
                .foregroundColor: UIColor.label,
                .font: UIFont.boldSystemFont(ofSize: 30)
            ]
        )
        let tracklyBlue = UIColor(red: 0/255.0, green: 107/255.0, blue: 255/255.0, alpha: 1.0) // #006BFF
        title.append(NSAttributedString(
            string: "ly",
            attributes: [
                .foregroundColor: tracklyBlue,
                .font: UIFont.boldSystemFont(ofSize: 30)
            ]
        ))
        label.attributedText = title
        navigationItem.titleView = label
    }
}
