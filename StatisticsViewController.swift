import UIKit

// MARK: - StatisticsViewController
final class StatisticsViewController: UIViewController {

    // MARK: - UI

    // Üst başlık ve dönem kontrolü
    private let header = UIStackView()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let periodLabel = UILabel()

    private let periodControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Hafta", "Ay", "Yıl"])
        sc.selectedSegmentIndex = 0
        return sc
    }()

    private let totalLabel = UILabel()

    // Scrollable içerik
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()

    // 4 kart
    private let kcalCard = UIView()
    private let kmCard = UIView()
    private let durationCard = UIView()
    private let paceCard = UIView()

    private let kcalValueLabel = UILabel()
    private let kmValueLabel = UILabel()
    private let durationValueLabel = UILabel()
    private let paceValueLabel = UILabel()
    private let summaryLabel = UILabel()

    // 4 grafik container (Kalori, Mesafe, Süre, Tempo)
    private let kcalChartContainer = UIView()
    private let kmChartContainer = UIView()
    private let durationChartContainer = UIView()
    private let paceChartContainer = UIView()

    // MARK: - Chart State

    private struct ChartState {
        var stacks: [UIStackView] = []
        var bars: [UIView] = []
        var valueLabels: [UILabel] = []
        var dayLabels: [UILabel] = []
        var heightConstraints: [NSLayoutConstraint] = []
    }

    private var kcalChart = ChartState()
    private var kmChart = ChartState()
    private var durationChart = ChartState()
    private var paceChart = ChartState()

    // MARK: - State

    private enum Period: Int {
        case week = 0
        case month
        case year
    }

    private var period: Period = .week
    private var weekOffset: Int = 0
    private var monthOffset: Int = 0
    private var yearOffset: Int = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        applyBrandTitle()
        title = "İstatistikler"
        view.backgroundColor = .systemBackground
        setupUI()
        reloadChart()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // ScrollView + ContentView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // Ana dikey stack
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])

        // Header (prev | label | next)
        header.axis = .horizontal
        header.alignment = .center
        header.distribution = .equalCentering
        header.spacing = 12

        prevButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        prevButton.addTarget(self, action: #selector(prevPeriod), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextPeriod), for: .touchUpInside)

        periodLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        periodLabel.textColor = .label
        periodLabel.textAlignment = .center
        periodLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        header.addArrangedSubview(prevButton)
        header.addArrangedSubview(periodLabel)
        header.addArrangedSubview(nextButton)
        prevButton.setContentHuggingPriority(.required, for: .horizontal)
        nextButton.setContentHuggingPriority(.required, for: .horizontal)
        prevButton.widthAnchor.constraint(equalTo: nextButton.widthAnchor).isActive = true

        // Period segmented control
        periodControl.translatesAutoresizingMaskIntoConstraints = false
        periodControl.addTarget(self, action: #selector(periodChanged(_:)), for: .valueChanged)

        // Toplam label
        totalLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        totalLabel.textColor = .label
        totalLabel.textAlignment = .left

        // Kart stilleri
        func styleCard(_ v: UIView) {
            v.backgroundColor = .tertiarySystemBackground
            v.layer.cornerRadius = 14
            v.layer.borderWidth = 0.5
            v.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        styleCard(kcalCard)
        styleCard(kmCard)
        styleCard(durationCard)
        styleCard(paceCard)

        // 4 kart içeriği
        setupKcalCard()
        setupKmCard()
        setupDurationCard()
        setupPaceCard()

        // 4 grafik container
        [kcalChartContainer, kmChartContainer, durationChartContainer, paceChartContainer].forEach { container in
            container.translatesAutoresizingMaskIntoConstraints = false
            container.backgroundColor = .secondarySystemBackground
            container.layer.cornerRadius = 16
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        }

        summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 2

        // Stack’e sıralı ekleme:
        // Kalori istatistiği, Kalori grafiği,
        // Mesafe istatistiği, Mesafe grafiği,
        // Süre istatistiği, Süre grafiği,
        // Tempo istatistiği, Tempo grafiği, Özet
        contentStack.addArrangedSubview(header)
        contentStack.addArrangedSubview(periodControl)
        contentStack.setCustomSpacing(8, after: periodControl)
        contentStack.addArrangedSubview(totalLabel)
        contentStack.setCustomSpacing(12, after: totalLabel)

        contentStack.addArrangedSubview(kcalCard)
        contentStack.addArrangedSubview(kcalChartContainer)

        contentStack.addArrangedSubview(kmCard)
        contentStack.addArrangedSubview(kmChartContainer)

        contentStack.addArrangedSubview(durationCard)
        contentStack.addArrangedSubview(durationChartContainer)

        contentStack.addArrangedSubview(paceCard)
        contentStack.addArrangedSubview(paceChartContainer)

        contentStack.addArrangedSubview(summaryLabel)
    }

    // MARK: - Card Setup

    private func setupKcalCard() {
        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = .secondarySystemBackground
        iconWrap.layer.cornerRadius = 14

        let icon = UIImageView(image: UIImage(systemName: "flame.fill"))
        icon.tintColor = UIColor(red: 1.0, green: 0.42, blue: 0.24, alpha: 1.0) // turuncu
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        iconWrap.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            iconWrap.widthAnchor.constraint(equalToConstant: 28),
            iconWrap.heightAnchor.constraint(equalToConstant: 28)
        ])

        let title = UILabel()
        title.text = "Kalori"
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabel

        let headerStack = UIStackView(arrangedSubviews: [iconWrap, title])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8

        kcalValueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        kcalValueLabel.textColor = .label
        kcalValueLabel.textAlignment = .right

        let hStack = UIStackView(arrangedSubviews: [headerStack, kcalValueLabel])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.distribution = .equalSpacing
        hStack.spacing = 8
        hStack.isLayoutMarginsRelativeArrangement = true
        hStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        hStack.translatesAutoresizingMaskIntoConstraints = false

        // Başlık solda, değer sağda kalsın diye hugging/ compression ayarları
        headerStack.setContentHuggingPriority(.required, for: .horizontal)
        kcalValueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        kcalValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        kcalCard.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: kcalCard.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: kcalCard.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: kcalCard.trailingAnchor),
            hStack.bottomAnchor.constraint(equalTo: kcalCard.bottomAnchor),
            kcalCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
    }

    private func setupKmCard() {
        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = .secondarySystemBackground
        iconWrap.layer.cornerRadius = 14

        let icon = UIImageView(image: UIImage(systemName: "figure.run.circle.fill"))
        icon.tintColor = UIColor(red: 0/255.0, green: 107/255.0, blue: 255/255.0, alpha: 1.0) // Trackly mavisi
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        iconWrap.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            iconWrap.widthAnchor.constraint(equalToConstant: 28),
            iconWrap.heightAnchor.constraint(equalToConstant: 28)
        ])

        let title = UILabel()
        title.text = "Mesafe"
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabel

        let headerStack = UIStackView(arrangedSubviews: [iconWrap, title])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8

        kmValueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        kmValueLabel.textColor = .label
        kmValueLabel.textAlignment = .right

        let hStack = UIStackView(arrangedSubviews: [headerStack, kmValueLabel])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.distribution = .equalSpacing
        hStack.spacing = 8
        hStack.isLayoutMarginsRelativeArrangement = true
        hStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        hStack.translatesAutoresizingMaskIntoConstraints = false

        headerStack.setContentHuggingPriority(.required, for: .horizontal)
        kmValueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        kmValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        kmCard.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: kmCard.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: kmCard.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: kmCard.trailingAnchor),
            hStack.bottomAnchor.constraint(equalTo: kmCard.bottomAnchor),
            kmCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
    }

    private func setupDurationCard() {
        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = .secondarySystemBackground
        iconWrap.layer.cornerRadius = 14

        let icon = UIImageView(image: UIImage(systemName: "timer"))
        icon.tintColor = .systemPurple
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        iconWrap.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            iconWrap.widthAnchor.constraint(equalToConstant: 28),
            iconWrap.heightAnchor.constraint(equalToConstant: 28)
        ])

        let title = UILabel()
        title.text = "Süre"
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabel

        let headerStack = UIStackView(arrangedSubviews: [iconWrap, title])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8

        durationValueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        durationValueLabel.textColor = .label
        durationValueLabel.textAlignment = .right

        let hStack = UIStackView(arrangedSubviews: [headerStack, durationValueLabel])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.distribution = .equalSpacing
        hStack.spacing = 8
        hStack.isLayoutMarginsRelativeArrangement = true
        hStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        hStack.translatesAutoresizingMaskIntoConstraints = false

        headerStack.setContentHuggingPriority(.required, for: .horizontal)
        durationValueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        durationValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        durationCard.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: durationCard.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: durationCard.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: durationCard.trailingAnchor),
            hStack.bottomAnchor.constraint(equalTo: durationCard.bottomAnchor),
            durationCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
    }

    private func setupPaceCard() {
        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = .secondarySystemBackground
        iconWrap.layer.cornerRadius = 14

        let icon = UIImageView(image: UIImage(systemName: "speedometer"))
        icon.tintColor = .systemGreen
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        iconWrap.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            iconWrap.widthAnchor.constraint(equalToConstant: 28),
            iconWrap.heightAnchor.constraint(equalToConstant: 28)
        ])

        let title = UILabel()
        title.text = "Tempo"
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabel

        let headerStack = UIStackView(arrangedSubviews: [iconWrap, title])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8

        paceValueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        paceValueLabel.textColor = .label
        paceValueLabel.textAlignment = .right

        let hStack = UIStackView(arrangedSubviews: [headerStack, paceValueLabel])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.distribution = .equalSpacing
        hStack.spacing = 8
        hStack.isLayoutMarginsRelativeArrangement = true
        hStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        hStack.translatesAutoresizingMaskIntoConstraints = false

        headerStack.setContentHuggingPriority(.required, for: .horizontal)
        paceValueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        paceValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        paceCard.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: paceCard.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: paceCard.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: paceCard.trailingAnchor),
            hStack.bottomAnchor.constraint(equalTo: paceCard.bottomAnchor),
            paceCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
    }

    // MARK: - Actions

    @objc private func periodChanged(_ sender: UISegmentedControl) {
        guard let newPeriod = Period(rawValue: sender.selectedSegmentIndex) else { return }
        period = newPeriod
        weekOffset = 0
        monthOffset = 0
        yearOffset = 0
        reloadChart()
    }

    @objc private func prevPeriod() {
        switch period {
        case .week:  weekOffset -= 1
        case .month: monthOffset -= 1
        case .year:  yearOffset -= 1
        }
        reloadChart()
    }

    @objc private func nextPeriod() {
        switch period {
        case .week:  weekOffset += 1
        case .month: monthOffset += 1
        case .year:  yearOffset += 1
        }
        reloadChart()
    }

    // MARK: - Data + Chart

    private func reloadChart() {
        let cal = Calendar.current
        let today = Date()

        // 1) Seçili dönemin tarih aralığı
        var rangeStart: Date
        var rangeEnd: Date

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

        // 2) Başlık metni
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

        // 3) O aralıktaki koşular
        let runs = RunStore.shared.runs.filter { $0.date >= rangeStart && $0.date < rangeEnd }

        // 4) Bucketlar
        var labels: [String] = []
        var kcalValues: [Double] = []
        var kmValues: [Double] = []
        var durationValues: [Int] = []
        var pacePerBucketSec: [Double] = []

        switch period {
        case .week:
            labels = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]
            var kcalPerDay = Array(repeating: 0.0, count: 7)
            var kmPerDay = Array(repeating: 0.0, count: 7)
            var durationPerDay = Array(repeating: 0, count: 7)

            for run in runs {
                let weekday = cal.component(.weekday, from: run.date) // 1=Sun...7=Sat
                let idx = (weekday + 5) % 7 // Pazartesi=0
                guard idx >= 0 && idx < 7 else { continue }
                kcalPerDay[idx] += run.calories
                kmPerDay[idx] += run.distanceKm
                durationPerDay[idx] += run.durationSeconds
            }
            kcalValues = kcalPerDay
            kmValues = kmPerDay
            durationValues = durationPerDay

        case .month:
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
            labels = ["1.Ç","2.Ç","3.Ç","4.Ç"]

            var kcalPerQuarter = Array(repeating: 0.0, count: 4)
            var kmPerQuarter = Array(repeating: 0.0, count: 4)
            var durationPerQuarter = Array(repeating: 0, count: 4)

            for run in runs {
                let m = cal.component(.month, from: run.date)
                var idx = (m - 1) / 3
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

        // Tempo (s/km) bucket bazında
        if !labels.isEmpty {
            pacePerBucketSec = (0..<labels.count).map { idx in
                let km = idx < kmValues.count ? kmValues[idx] : 0
                let dur = idx < durationValues.count ? durationValues[idx] : 0
                guard km > 0, dur > 0 else { return 0 }
                return Double(dur) / max(km, 0.0001)
            }
        }

        // 5) Barları tekrar oluştur
        buildBarChart(in: kcalChartContainer, chart: &kcalChart, labels: labels)
        buildBarChart(in: kmChartContainer, chart: &kmChart, labels: labels)
        buildBarChart(in: durationChartContainer, chart: &durationChart, labels: labels)
        buildBarChart(in: paceChartContainer, chart: &paceChart, labels: labels)

        // 6) Kart değerleri
        let totalKcal = kcalValues.reduce(0, +)
        let totalKm = kmValues.reduce(0, +)
        let totalDuration = runs.reduce(0) { $0 + $1.durationSeconds }
        let avgPaceSecPerKm: Double = totalKm > 0 ? Double(totalDuration) / totalKm : 0

        totalLabel.text = "Toplam: \(Int(totalKcal.rounded())) kcal"
        kcalValueLabel.text = "\(Int(totalKcal.rounded()))"
        kmValueLabel.text = String(format: "%.2f km", totalKm)
        durationValueLabel.text = formatDuration(totalDuration)
        paceValueLabel.text = formatPace(avgPaceSecPerKm)

        let runCount = runs.count
        let activeDays = Set(runs.map { cal.startOfDay(for: $0.date) }).count
        if runCount == 0 {
            summaryLabel.text = "Bu dönemde koşu yok"
        } else {
            summaryLabel.text = "Bu dönemde \(runCount) koşu • \(activeDays) aktif gün"
        }

        // 7) Grafik yükseklikleri

        // Kalori grafiği
        kcalChartContainer.layoutIfNeeded()
        let kcalAvailable = max(kcalChartContainer.bounds.height - 64, 60)
        let kcalMaxHeight = min(kcalAvailable, 120)
        let maxKcalVal = max(kcalValues.max() ?? 0, 0.0001)

        for i in 0..<labels.count {
            let v = i < kcalValues.count ? kcalValues[i] : 0
            if i < kcalChart.valueLabels.count {
                kcalChart.valueLabels[i].text = v < 1 ? "0" : String(Int(v.rounded()))
            }
            let ratio = CGFloat(v / maxKcalVal)
            let h = max(4, ratio * kcalMaxHeight)
            if i < kcalChart.heightConstraints.count {
                kcalChart.heightConstraints[i].constant = h
            }
        }

        // Mesafe grafiği
        kmChartContainer.layoutIfNeeded()
        let kmAvailable = max(kmChartContainer.bounds.height - 64, 60)
        let kmMaxHeight = min(kmAvailable, 120)
        let maxKmVal = max(kmValues.max() ?? 0, 0.0001)

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
            let h = max(4, ratio * kmMaxHeight)
            if i < kmChart.heightConstraints.count {
                kmChart.heightConstraints[i].constant = h
            }
        }

        // Süre grafiği
        durationChartContainer.layoutIfNeeded()
        let durAvailable = max(durationChartContainer.bounds.height - 64, 60)
        let durMaxHeight = min(durAvailable, 120)
        let maxDuration = max(Double(durationValues.max() ?? 0), 0.0001)

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
            let h = max(4, ratio * durMaxHeight)
            if i < durationChart.heightConstraints.count {
                durationChart.heightConstraints[i].constant = h
            }
        }

        // Tempo grafiği (daha hızlı tempo -> daha yüksek bar)
        paceChartContainer.layoutIfNeeded()
        let paceAvailable = max(paceChartContainer.bounds.height - 64, 60)
        let paceMaxHeight = min(paceAvailable, 120)

        // Hız = 1 / pace (s/km)
        let paceSpeeds: [Double] = pacePerBucketSec.map { secPerKm in
            guard secPerKm > 0 else { return 0 }
            return 1.0 / secPerKm
        }
        let maxSpeed = max(paceSpeeds.max() ?? 0, 0.0001)

        for i in 0..<labels.count {
            let secPerKm = i < pacePerBucketSec.count ? pacePerBucketSec[i] : 0
            if secPerKm <= 0 {
                if i < paceChart.valueLabels.count {
                    paceChart.valueLabels[i].text = "0:00 /km"
                }
                if i < paceChart.heightConstraints.count {
                    paceChart.heightConstraints[i].constant = 4
                }
                continue
            }

            if i < paceChart.valueLabels.count {
                paceChart.valueLabels[i].text = formatPace(secPerKm)
            }
            let speed = paceSpeeds[i]
            let ratio = CGFloat(speed / maxSpeed)
            let h = max(4, ratio * paceMaxHeight)
            if i < paceChart.heightConstraints.count {
                paceChart.heightConstraints[i].constant = h
            }
        }
    }

    // MARK: - Chart Builder

    private func buildBarChart(
        in container: UIView,
        chart: inout ChartState,
        labels: [String]
    ) {
        // Temizle
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

            let valueLabel = UILabel()
            valueLabel.text = "0"
            valueLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            valueLabel.textColor = .secondaryLabel
            valueLabel.textAlignment = .center

            let barHost = UIView()
            barHost.translatesAutoresizingMaskIntoConstraints = false
            barHost.backgroundColor = .clear

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
        let tracklyBlue = UIColor(red: 0/255.0, green: 107/255.0, blue: 255/255.0, alpha: 1.0)
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
