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
    private let durationCard = UIView()
    private let paceCard = UIView()

    private let kcalValueLabel = UILabel()
    private let kmValueLabel = UILabel()
    private let durationValueLabel = UILabel()
    private let paceValueLabel = UILabel()
    private let summaryLabel = UILabel()
    
    private var barStacks: [UIStackView] = []
    private var barViews: [UIView] = []
    private var valueLabels: [UILabel] = []
    private var dayLabels: [UILabel] = []
    private var barHeightConstraints: [NSLayoutConstraint] = []

    private let periodControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Hafta", "Ay", "Yıl"])
        sc.selectedSegmentIndex = 0 // varsayılan: Hafta
        return sc
    }()

    // MARK: State
    private var weekOffset: Int = 0   // 0: bu hafta, -1: geçen hafta, +1: sonraki hafta
    private var monthOffset: Int = 0  // 0: bu ay, -1: geçen ay, +1: sonraki ay
    private var yearOffset: Int = 0   // 0: bu yıl, -1: geçen yıl, +1: sonraki yıl
    private enum Period: Int {
        case week = 0
        case month
        case year
    }
    private var period: Period = .week

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

        periodControl.translatesAutoresizingMaskIntoConstraints = false
        periodControl.addTarget(self, action: #selector(periodChanged(_:)), for: .valueChanged)

        view.addSubview(header)
        view.addSubview(periodControl)
        view.addSubview(totalLabel)
        view.addSubview(chartContainer)
        view.addSubview(statsRow)

        NSLayoutConstraint.activate([
            // Header pinned to top
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            periodControl.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            periodControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            periodControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Total label just under period control
            totalLabel.topAnchor.constraint(equalTo: periodControl.bottomAnchor, constant: 8),
            totalLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            totalLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            // Chart as a rounded panel
            chartContainer.topAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: 8),
            chartContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            chartContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            chartContainer.bottomAnchor.constraint(equalTo: statsRow.topAnchor, constant: -12),

            // Stats column below chart
            statsRow.topAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: 12),
            statsRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statsRow.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])

        // Stats column (vertical: 2 satır kart + özet label)
        statsRow.axis = .vertical
        statsRow.alignment = .fill
        statsRow.distribution = .fill
        statsRow.spacing = 12
        statsRow.translatesAutoresizingMaskIntoConstraints = false
    
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
    
        // --- Kcal card (ikon + başlık + büyük değer) ---
        let flameIconWrap = UIView()
        flameIconWrap.translatesAutoresizingMaskIntoConstraints = false
        flameIconWrap.backgroundColor = .secondarySystemBackground
        flameIconWrap.layer.cornerRadius = 14

        let flameIcon = UIImageView(image: UIImage(systemName: "flame.fill"))
        flameIcon.tintColor = UIColor(hex: "#FF6B3D")
        flameIcon.contentMode = .scaleAspectFit
        flameIcon.translatesAutoresizingMaskIntoConstraints = false

        flameIconWrap.addSubview(flameIcon)
        NSLayoutConstraint.activate([
            flameIcon.centerXAnchor.constraint(equalTo: flameIconWrap.centerXAnchor),
            flameIcon.centerYAnchor.constraint(equalTo: flameIconWrap.centerYAnchor),
            flameIcon.widthAnchor.constraint(equalToConstant: 16),
            flameIcon.heightAnchor.constraint(equalToConstant: 16),
            flameIconWrap.widthAnchor.constraint(equalToConstant: 28),
            flameIconWrap.heightAnchor.constraint(equalToConstant: 28)
        ])

        let kcalTitle = UILabel()
        kcalTitle.text = "Kalori"
        kcalTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        kcalTitle.textColor = .secondaryLabel

        let kcalHeader = UIStackView(arrangedSubviews: [flameIconWrap, kcalTitle])
        kcalHeader.axis = .horizontal
        kcalHeader.alignment = .center
        kcalHeader.spacing = 8

        kcalValueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        kcalValueLabel.textColor = .label

        let kcalStack = UIStackView(arrangedSubviews: [kcalHeader, kcalValueLabel])
        kcalStack.axis = .vertical
        kcalStack.spacing = 8
        kcalStack.isLayoutMarginsRelativeArrangement = true
        kcalStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        kcalStack.translatesAutoresizingMaskIntoConstraints = false
        kcalCard.addSubview(kcalStack)
        NSLayoutConstraint.activate([
            kcalStack.topAnchor.constraint(equalTo: kcalCard.topAnchor),
            kcalStack.leadingAnchor.constraint(equalTo: kcalCard.leadingAnchor),
            kcalStack.trailingAnchor.constraint(equalTo: kcalCard.trailingAnchor),
            kcalStack.bottomAnchor.constraint(equalTo: kcalCard.bottomAnchor),
            kcalCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
    
        // --- Km card (ikon + başlık + büyük değer) ---
        let distanceIconWrap = UIView()
        distanceIconWrap.translatesAutoresizingMaskIntoConstraints = false
        distanceIconWrap.backgroundColor = .secondarySystemBackground
        distanceIconWrap.layer.cornerRadius = 14

        let distanceIcon = UIImageView(image: UIImage(systemName: "figure.run.circle.fill"))
        distanceIcon.tintColor = UIColor(hex: "#006BFF")
        distanceIcon.contentMode = .scaleAspectFit
        distanceIcon.translatesAutoresizingMaskIntoConstraints = false

        distanceIconWrap.addSubview(distanceIcon)
        NSLayoutConstraint.activate([
            distanceIcon.centerXAnchor.constraint(equalTo: distanceIconWrap.centerXAnchor),
            distanceIcon.centerYAnchor.constraint(equalTo: distanceIconWrap.centerYAnchor),
            distanceIcon.widthAnchor.constraint(equalToConstant: 18),
            distanceIcon.heightAnchor.constraint(equalToConstant: 18),
            distanceIconWrap.widthAnchor.constraint(equalToConstant: 28),
            distanceIconWrap.heightAnchor.constraint(equalToConstant: 28)
        ])

        let kmTitle = UILabel()
        kmTitle.text = "Mesafe"
        kmTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        kmTitle.textColor = .secondaryLabel

        let kmHeader = UIStackView(arrangedSubviews: [distanceIconWrap, kmTitle])
        kmHeader.axis = .horizontal
        kmHeader.alignment = .center
        kmHeader.spacing = 8

        kmValueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        kmValueLabel.textColor = .label

        let kmStack = UIStackView(arrangedSubviews: [kmHeader, kmValueLabel])
        kmStack.axis = .vertical
        kmStack.spacing = 8
        kmStack.isLayoutMarginsRelativeArrangement = true
        kmStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        kmStack.translatesAutoresizingMaskIntoConstraints = false
        kmCard.addSubview(kmStack)
        NSLayoutConstraint.activate([
            kmStack.topAnchor.constraint(equalTo: kmCard.topAnchor),
            kmStack.leadingAnchor.constraint(equalTo: kmCard.leadingAnchor),
            kmStack.trailingAnchor.constraint(equalTo: kmCard.trailingAnchor),
            kmStack.bottomAnchor.constraint(equalTo: kmCard.bottomAnchor),
            kmCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])

        // --- Duration card (ikon + başlık + büyük değer) ---
        let durationIconWrap = UIView()
        durationIconWrap.translatesAutoresizingMaskIntoConstraints = false
        durationIconWrap.backgroundColor = .secondarySystemBackground
        durationIconWrap.layer.cornerRadius = 14

        let durationIcon = UIImageView(image: UIImage(systemName: "timer"))
        durationIcon.tintColor = .systemPurple
        durationIcon.contentMode = .scaleAspectFit
        durationIcon.translatesAutoresizingMaskIntoConstraints = false

        durationIconWrap.addSubview(durationIcon)
        NSLayoutConstraint.activate([
            durationIcon.centerXAnchor.constraint(equalTo: durationIconWrap.centerXAnchor),
            durationIcon.centerYAnchor.constraint(equalTo: durationIconWrap.centerYAnchor),
            durationIcon.widthAnchor.constraint(equalToConstant: 16),
            durationIcon.heightAnchor.constraint(equalToConstant: 16),
            durationIconWrap.widthAnchor.constraint(equalToConstant: 28),
            durationIconWrap.heightAnchor.constraint(equalToConstant: 28)
        ])

        let durationTitle = UILabel()
        durationTitle.text = "Süre"
        durationTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        durationTitle.textColor = .secondaryLabel

        let durationHeader = UIStackView(arrangedSubviews: [durationIconWrap, durationTitle])
        durationHeader.axis = .horizontal
        durationHeader.alignment = .center
        durationHeader.spacing = 8

        durationValueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        durationValueLabel.textColor = .label

        let durationStack = UIStackView(arrangedSubviews: [durationHeader, durationValueLabel])
        durationStack.axis = .vertical
        durationStack.spacing = 8
        durationStack.isLayoutMarginsRelativeArrangement = true
        durationStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        durationStack.translatesAutoresizingMaskIntoConstraints = false
        durationCard.addSubview(durationStack)
        NSLayoutConstraint.activate([
            durationStack.topAnchor.constraint(equalTo: durationCard.topAnchor),
            durationStack.leadingAnchor.constraint(equalTo: durationCard.leadingAnchor),
            durationStack.trailingAnchor.constraint(equalTo: durationCard.trailingAnchor),
            durationStack.bottomAnchor.constraint(equalTo: durationCard.bottomAnchor),
            durationCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])

        // --- Pace card (ikon + başlık + büyük değer) ---
        let paceIconWrap = UIView()
        paceIconWrap.translatesAutoresizingMaskIntoConstraints = false
        paceIconWrap.backgroundColor = .secondarySystemBackground
        paceIconWrap.layer.cornerRadius = 14

        let paceIcon = UIImageView(image: UIImage(systemName: "speedometer"))
        paceIcon.tintColor = .systemGreen
        paceIcon.contentMode = .scaleAspectFit
        paceIcon.translatesAutoresizingMaskIntoConstraints = false

        paceIconWrap.addSubview(paceIcon)
        NSLayoutConstraint.activate([
            paceIcon.centerXAnchor.constraint(equalTo: paceIconWrap.centerXAnchor),
            paceIcon.centerYAnchor.constraint(equalTo: paceIconWrap.centerYAnchor),
            paceIcon.widthAnchor.constraint(equalToConstant: 18),
            paceIcon.heightAnchor.constraint(equalToConstant: 18),
            paceIconWrap.widthAnchor.constraint(equalToConstant: 28),
            paceIconWrap.heightAnchor.constraint(equalToConstant: 28)
        ])

        let paceTitle = UILabel()
        paceTitle.text = "Tempo"
        paceTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        paceTitle.textColor = .secondaryLabel

        let paceHeader = UIStackView(arrangedSubviews: [paceIconWrap, paceTitle])
        paceHeader.axis = .horizontal
        paceHeader.alignment = .center
        paceHeader.spacing = 8

        paceValueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        paceValueLabel.textColor = .label

        let paceStack = UIStackView(arrangedSubviews: [paceHeader, paceValueLabel])
        paceStack.axis = .vertical
        paceStack.spacing = 8
        paceStack.isLayoutMarginsRelativeArrangement = true
        paceStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        paceStack.translatesAutoresizingMaskIntoConstraints = false
        paceCard.addSubview(paceStack)
        NSLayoutConstraint.activate([
            paceStack.topAnchor.constraint(equalTo: paceCard.topAnchor),
            paceStack.leadingAnchor.constraint(equalTo: paceCard.leadingAnchor),
            paceStack.trailingAnchor.constraint(equalTo: paceCard.trailingAnchor),
            paceStack.bottomAnchor.constraint(equalTo: paceCard.bottomAnchor),
            paceCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])

        // Üst satır: Süre (sol) + Mesafe (sağ)
        let firstRow = UIStackView(arrangedSubviews: [durationCard, kmCard])
        firstRow.axis = .horizontal
        firstRow.alignment = .fill
        firstRow.distribution = .fillEqually
        firstRow.spacing = 12

        // Alt satır: Kalori (sol) + Tempo (sağ)
        let secondRow = UIStackView(arrangedSubviews: [kcalCard, paceCard])
        secondRow.axis = .horizontal
        secondRow.alignment = .fill
        secondRow.distribution = .fillEqually
        secondRow.spacing = 12

        summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 2

        statsRow.addArrangedSubview(firstRow)
        statsRow.addArrangedSubview(secondRow)
        statsRow.addArrangedSubview(summaryLabel)
        
        buildBars()
    }

    // Dinamik bar oluşturucu: verilen etiket sayısına göre kolon oluşturur
    private func buildBars(labels: [String]) {
        // Temizle
        chartContainer.subviews.forEach { $0.removeFromSuperview() }
        barStacks.removeAll()
        barViews.removeAll()
        valueLabels.removeAll()
        dayLabels.removeAll()
        barHeightConstraints.removeAll()

        // Yatay grid
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

        for labelText in labels {
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

            // Bar host
            let barHost = UIView()
            barHost.translatesAutoresizingMaskIntoConstraints = false
            barHost.backgroundColor = .clear

            let bar = UIView()
            bar.backgroundColor = UIColor(hex: "#006BFF")
            bar.layer.cornerRadius = 6
            bar.translatesAutoresizingMaskIntoConstraints = false
            barHost.addSubview(bar)

            let barBottom = bar.bottomAnchor.constraint(equalTo: barHost.bottomAnchor)
            let barWidth  = bar.widthAnchor.constraint(equalTo: barHost.widthAnchor, multiplier: 0.6)
            let barCenter = bar.centerXAnchor.constraint(equalTo: barHost.centerXAnchor)
            let barHeight = bar.heightAnchor.constraint(equalToConstant: 4)
            NSLayoutConstraint.activate([barBottom, barWidth, barCenter, barHeight])
            barHeightConstraints.append(barHeight)

            // Eksen etiketi (gün / hafta / ay ismi)
            let day = UILabel()
            day.text = labelText
            day.font = .systemFont(ofSize: 12, weight: .regular)
            day.textColor = .secondaryLabel
            day.textAlignment = .center

            // Yükseklik
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

    // Varsayılan (ilk açılış için) haftalık görünüm: Pazartesi–Pazar
    private func buildBars() {
        let dayShorts = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]
        buildBars(labels: dayShorts)
    }

    // MARK: Data + Chart
    private struct DayStat {
        let date: Date
        let kcal: Double
        let km: Double
    }

    @objc private func periodChanged(_ sender: UISegmentedControl) {
        guard let newPeriod = Period(rawValue: sender.selectedSegmentIndex) else { return }
        period = newPeriod
        // Her mod değiştirdiğinde ofsetleri sıfırla
        weekOffset = 0
        monthOffset = 0
        yearOffset = 0
        reloadChart()
    }

    @objc private func metricChanged() { reloadChart() }

    @objc private func prevWeek() {
        switch period {
        case .week:
            weekOffset -= 1
        case .month:
            monthOffset -= 1
        case .year:
            yearOffset -= 1
        }
        reloadChart()
    }

    @objc private func nextWeek() {
        switch period {
        case .week:
            weekOffset += 1
        case .month:
            monthOffset += 1
        case .year:
            yearOffset += 1
        }
        reloadChart()
    }

    private func reloadChart() {
        let cal = Calendar.current
        let today = Date()

        // 1) Seçili döneme göre tarih aralığını belirle
        var rangeStart: Date
        var rangeEnd: Date

        switch period {
        case .week:
            let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: today)!
            rangeStart = startOfWeek(for: base)
            rangeEnd = cal.date(byAdding: .day, value: 7, to: rangeStart)!
        case .month:
            let baseMonth = cal.date(byAdding: .month, value: monthOffset, to: today) ?? today
            let comps = cal.dateComponents([.year, .month], from: baseMonth)
            rangeStart = cal.date(from: comps) ?? baseMonth
            rangeEnd = cal.date(byAdding: .month, value: 1, to: rangeStart) ?? rangeStart
        case .year:
            let baseYear = cal.date(byAdding: .year, value: yearOffset, to: today) ?? today
            let comps = cal.dateComponents([.year], from: baseYear)
            rangeStart = cal.date(from: comps) ?? baseYear
            rangeEnd = cal.date(byAdding: .year, value: 1, to: rangeStart) ?? rangeStart
        }

        // 2) Başlıktaki tarih metni
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
        switch period {
        case .week:
            df.dateFormat = "d MMM"
            let endTitle = cal.date(byAdding: .day, value: 6, to: rangeStart) ?? rangeStart
            weekLabel.text = "\(df.string(from: rangeStart)) – \(df.string(from: endTitle))"
        case .month:
            df.dateFormat = "LLLL yyyy"
            weekLabel.text = df.string(from: rangeStart)
        case .year:
            df.dateFormat = "yyyy"
            weekLabel.text = df.string(from: rangeStart)
        }

        // 3) Bu aralıktaki koşuları al
        let runs = RunStore.shared.runs.filter { $0.date >= rangeStart && $0.date < rangeEnd }

        // 4) Döneme göre bucket + label hazırla
        var labels: [String] = []
        var kcalValues: [Double] = []
        var kmValues: [Double] = []

        switch period {
        case .week:
            // 7 bar: Pazartesi–Pazar
            labels = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]
            var kcalPerDay = Array(repeating: 0.0, count: 7)
            var kmPerDay = Array(repeating: 0.0, count: 7)

            for run in runs {
                let weekday = cal.component(.weekday, from: run.date) // 1=Sun…7=Sat
                let idx = (weekday + 5) % 7 // Pazartesi=0
                guard idx >= 0 && idx < 7 else { continue }
                kcalPerDay[idx] += run.calories
                kmPerDay[idx] += run.distanceKm
            }
            kcalValues = kcalPerDay
            kmValues = kmPerDay

        case .month:
            // Bu ayı 7 günlük bloklara böl: 1–7, 8–14, 15–21, 22–28, 29–31
            let dayRange = cal.range(of: .day, in: .month, for: rangeStart) ?? 1..<29
            let daysInMonth = dayRange.count
            let bucketCount = Int(ceil(Double(daysInMonth) / 7.0))

            // X ekseni etiketleri: "1–7", "8–14" ...
            labels = (0..<bucketCount).map { idx in
                let startDay = idx * 7 + 1
                let endDay = min(startDay + 6, daysInMonth)
                return "\(startDay)–\(endDay)"
            }

            var kcalPerBucket = Array(repeating: 0.0, count: bucketCount)
            var kmPerBucket = Array(repeating: 0.0, count: bucketCount)

            for run in runs {
                let day = cal.component(.day, from: run.date)
                let idx = (day - 1) / 7 // 0,1,2,3,4
                guard idx >= 0 && idx < bucketCount else { continue }
                kcalPerBucket[idx] += run.calories
                kmPerBucket[idx] += run.distanceKm
            }

            kcalValues = kcalPerBucket
            kmValues = kmPerBucket

        case .year:
            // 4 bar: yılın çeyrekleri (1.Ç, 2.Ç, 3.Ç, 4.Ç)
            labels = ["1.Ç","2.Ç","3.Ç","4.Ç"]

            var kcalPerQuarter = Array(repeating: 0.0, count: 4)
            var kmPerQuarter = Array(repeating: 0.0, count: 4)

            for run in runs {
                let month = cal.component(.month, from: run.date) // 1...12
                var idx = (month - 1) / 3 // 0..3
                if idx < 0 { idx = 0 }
                if idx > 3 { idx = 3 }
                kcalPerQuarter[idx] += run.calories
                kmPerQuarter[idx] += run.distanceKm
            }

            kcalValues = kcalPerQuarter
            kmValues = kmPerQuarter
        }

        // 5) Barları yeni label sayısına göre yeniden kur
        buildBars(labels: labels)

        // 6) Toplamlar ve ek metrikler (kartlar + küçük toplam etiketi)
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

        // 7) Bar yükseklikleri
        chartContainer.layoutIfNeeded()
        let available = max(chartContainer.bounds.height - 64, 60)
        let maxBarHeight = min(available, 120)
        let maxVal = max(kcalValues.max() ?? 0, 0.0001)

        for i in 0..<labels.count {
            let v = kcalValues[i]
            valueLabels[i].text = v < 1 ? "0" : String(Int(v.rounded()))

            let ratio = CGFloat(v / maxVal)
            let h = max(4, ratio * maxBarHeight)

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
