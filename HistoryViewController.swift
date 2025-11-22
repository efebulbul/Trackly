import UIKit
import MapKit

final class HistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let periodControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Hafta", "Ay", "Yıl"])
        sc.selectedSegmentIndex = 0
        return sc
    }()
    private let rangeHeader = UIStackView()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let rangeLabel = UILabel()
    private var periodOffset: Int = 0
    private var currentPeriod: RunStore.Period = .week
    private var data: [Run] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Üst başlık: Trackly (ly mavi)
        applyBrandTitle()

        periodControl.translatesAutoresizingMaskIntoConstraints = false

        // Üstte dönem seçimi (Hafta/Ay/Yıl/Tümü)
        view.addSubview(periodControl)

        // Altına tarih aralığı navigasyonu (haftalar/aylar/yıllar arası geçiş)
        rangeHeader.axis = .horizontal
        rangeHeader.alignment = .center
        rangeHeader.distribution = .equalCentering
        rangeHeader.spacing = 12
        rangeHeader.translatesAutoresizingMaskIntoConstraints = false

        prevButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        prevButton.addTarget(self, action: #selector(prevRange), for: .touchUpInside)

        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextRange), for: .touchUpInside)

        rangeLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        rangeLabel.textColor = .label
        rangeLabel.textAlignment = .center
        rangeLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        rangeHeader.addArrangedSubview(prevButton)
        rangeHeader.addArrangedSubview(rangeLabel)
        rangeHeader.addArrangedSubview(nextButton)
        prevButton.setContentHuggingPriority(.required, for: .horizontal)
        nextButton.setContentHuggingPriority(.required, for: .horizontal)
        prevButton.widthAnchor.constraint(equalTo: nextButton.widthAnchor).isActive = true
        rangeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        view.addSubview(rangeHeader)

        NSLayoutConstraint.activate([
            rangeHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            rangeHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            rangeHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            periodControl.topAnchor.constraint(equalTo: rangeHeader.bottomAnchor, constant: 8),
            periodControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            periodControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        // Dönem değişimi (UI'da göstermiyoruz ama filtre mantığı korunuyor)
        periodControl.addTarget(self, action: #selector(periodChanged), for: .valueChanged)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: periodControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    @objc private func periodChanged() {
        let idx = periodControl.selectedSegmentIndex
        let all: [RunStore.Period] = [.week, .month, .year]
        currentPeriod = all[idx]
        periodOffset = 0
        reloadData()
    }

    private func reloadData() {
        let cal = Calendar.current
        let now = Date()

        var start: Date
        var end: Date
        var labelText: String

        switch currentPeriod {
        case .week:
            let base = cal.date(byAdding: .weekOfYear, value: periodOffset, to: now) ?? now
            start = startOfWeek(for: base)
            end = cal.date(byAdding: .day, value: 7, to: start)!

            let df = DateFormatter()
            df.locale = Locale(identifier: "tr_TR")
            df.dateFormat = "d MMM"
            let endLabelDate = cal.date(byAdding: .day, value: 6, to: start)!
            labelText = "\(df.string(from: start)) – \(df.string(from: endLabelDate))"

        case .month:
            let base = cal.date(byAdding: .month, value: periodOffset, to: now) ?? now
            start = startOfMonth(for: base)
            end = cal.date(byAdding: .month, value: 1, to: start)!

            let df = DateFormatter()
            df.locale = Locale(identifier: "tr_TR")
            df.dateFormat = "LLLL yyyy"
            labelText = df.string(from: start).capitalized

        case .year:
            let base = cal.date(byAdding: .year, value: periodOffset, to: now) ?? now
            start = startOfYear(for: base)
            end = cal.date(byAdding: .year, value: 1, to: start)!

            let df = DateFormatter()
            df.locale = Locale(identifier: "tr_TR")
            df.dateFormat = "yyyy"
            labelText = df.string(from: start)

        default:
            start = Date.distantPast
            end = Date.distantFuture
            labelText = ""
        }

        rangeLabel.text = labelText

        data = RunStore.shared.runs
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date > $1.date }

        tableView.tableHeaderView = nil
        if data.isEmpty {
            applyEmptyState()
        } else {
            tableView.backgroundView = nil
        }
        tableView.reloadData()
    }

    // Empty-state background
    private func applyEmptyState() {
        let label = UILabel()
        label.text = "Bu dönemde koşu yok"
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20)
        ])
        tableView.backgroundView = container
    }

    // MARK: - Branded Title
    private func applyBrandTitle() {
        let label = UILabel()
        let title = NSMutableAttributedString(
            string: "Track",
            attributes: [
                .foregroundColor: UIColor.label,
                .font: UIFont.boldSystemFont(ofSize: 30)
            ]
        )
        title.append(NSAttributedString(
            string: "ly",
            attributes: [
                .foregroundColor: UIColor(hex: "#006BFF"),
                .font: UIFont.boldSystemFont(ofSize: 30)
            ]
        ))
        label.attributedText = title
        navigationItem.titleView = label
    }

    // MARK: - Table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { data.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let run = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var conf = cell.defaultContentConfiguration()

        // Sadece koşu ismi
        conf.text = run.name
        conf.textProperties.font = .systemFont(ofSize: 16, weight: .semibold)
        conf.textProperties.color = .label
        conf.secondaryText = nil

        // Solda koşu ikonu (Trackly mavisi)
        conf.image = UIImage(systemName: "figure.run")
        conf.imageProperties.tintColor = UIColor(hex: "#006BFF")
        conf.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)

        cell.contentConfiguration = conf
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let run = data[indexPath.row]
        let vc = RunDetailViewController(run: run)
        navigationController?.pushViewController(vc, animated: true)
    }

    // Silme (Swipe to delete)
    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let run = data[indexPath.row]
            RunStore.shared.delete(id: run.id)
            data.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    @objc private func prevRange() {
        periodOffset -= 1
        reloadData()
    }

    @objc private func nextRange() {
        periodOffset += 1
        reloadData()
    }

    private func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Pazartesi
        var start = date
        var interval: TimeInterval = 0
        if cal.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: date) != nil {
            return start
        }
        return date
    }

    private func startOfMonth(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    private func startOfYear(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year], from: date)
        return cal.date(from: comps) ?? date
    }
}

// MARK: - Detay Ekranı
final class RunDetailViewController: UIViewController, MKMapViewDelegate {
    private let run: Run
    private let map = MKMapView()
    private let stack = UIStackView()
    private var durRow: UIStackView!
    private var distRow: UIStackView!
    private var paceRow: UIStackView!
    private var kcalRow: UIStackView!

    private var leftCol: UIStackView!
    private var rightCol: UIStackView!
    private var metricsGrid: UIStackView!

    init(run: Run) {
        self.run = run
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = run.name
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Sil", style: .plain, target: self, action: #selector(deleteRun))

        map.translatesAutoresizingMaskIntoConstraints = false
        map.delegate = self
        view.addSubview(map)

        stack.axis = .vertical
        stack.spacing = 8
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // 2x2 symmetric metric grid (cards)
        durRow  = makeMetricCard(title: "Süre",   value: hms(run.durationSeconds), icon: "timer")
        distRow = makeMetricCard(title: "Mesafe", value: String(format: "%.2f km", run.distanceKm), icon: "figure.run.circle.fill")
        paceRow = makeMetricCard(title: "Tempo",  value: paceText(run.avgPaceSecPerKm), icon: "speedometer")
        kcalRow = makeMetricCard(title: "Kalori", value: String(Int(run.calories.rounded())), icon: "flame.fill")
    
        leftCol = UIStackView(arrangedSubviews: [durRow, kcalRow])
        leftCol.axis = .vertical
        leftCol.spacing = 16
    
        rightCol = UIStackView(arrangedSubviews: [distRow, paceRow])
        rightCol.axis = .vertical
        rightCol.spacing = 16
    
        metricsGrid = UIStackView(arrangedSubviews: [leftCol, rightCol])
        metricsGrid.axis = .horizontal
        metricsGrid.distribution = .fillEqually
        metricsGrid.alignment = .fill
        metricsGrid.spacing = 12
        metricsGrid.translatesAutoresizingMaskIntoConstraints = false

        // En alta, metriklerin altında tam genişlik bir "Adım" kartı ekle
        // Adım sayısını mesafeye göre yaklaşık hesapla (aynı mantık: ~1300 adım / km)
        let approxSteps = Int((run.distanceKm * 1300).rounded())
        let stepsRow = makeStepsCard(steps: approxSteps)

        // Görsel olarak biraz nefes alan bir layout için spacing'i artır
        stack.spacing = 16
        stack.addArrangedSubview(metricsGrid)
        stack.addArrangedSubview(stepsRow)

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),

            stack.topAnchor.constraint(equalTo: map.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        drawRoute()
    }

    private func drawRoute() {
        let coords = run.route.map { $0.coordinate }
        guard coords.count >= 2 else { return }
        let poly = MKPolyline(coordinates: coords, count: coords.count)
        map.addOverlay(poly)
        map.setVisibleMapRect(poly.boundingMapRect,
                              edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                              animated: false)
    }

    // Koşuyu sil
    @objc private func deleteRun() {
        let alert = UIAlertController(title: "Koşuyu Sil",
                                      message: "Bu koşuyu silmek istediğine emin misin?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Sil", style: .destructive, handler: { _ in
            RunStore.shared.delete(id: self.run.id)
            self.navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true, completion: nil)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let p = overlay as? MKPolyline {
            let r = MKPolylineRenderer(polyline: p)
            r.strokeColor = UIColor(hex: "#006BFF")
            r.lineWidth = 8
            r.lineJoin = .round
            r.lineCap = .round
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    private func labelRow(title: String, value: String) -> UIStackView {
        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 14, weight: .semibold)
        t.textColor = .secondaryLabel

        let v = UILabel()
        v.text = value
        v.font = .systemFont(ofSize: 20, weight: .bold)
        v.textColor = .label

        let row = UIStackView(arrangedSubviews: [t, UIView(), v])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        return row
    }

    private func hms(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%01d:%02d:%02d", h, m, s)
    }
    private func paceText(_ secPerKm: Double) -> String {
        guard secPerKm.isFinite, secPerKm > 0 else { return "0:00 /km" }
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }

    private func makeMetricCard(title: String, value: String, icon: String) -> UIStackView {
        // Outer card
        let card = UIView()
        card.backgroundColor = .tertiarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        // Icon badge (same style as StatisticsViewController)
        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = .secondarySystemBackground
        iconWrap.layer.cornerRadius = 14

        let iv = UIImageView(image: UIImage(systemName: icon))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit

        // Tint color mapping so that "Kalori" matches StatisticsViewController (#FF6B3D)
        if title == "Kalori" {
            iv.tintColor = UIColor(hex: "#FF6B3D")
        } else if title == "Mesafe" {
            iv.tintColor = UIColor(hex: "#006BFF")
        } else if title == "Tempo" {
            iv.tintColor = .systemGreen
        } else if title == "Süre" {
            iv.tintColor = .systemPurple
        } else {
            iv.tintColor = UIColor(hex: "#006BFF")
        }

        iconWrap.addSubview(iv)
        let iconSize: CGFloat = (title == "Mesafe") ? 18 : 16
        NSLayoutConstraint.activate([
            iv.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            iv.widthAnchor.constraint(equalToConstant: iconSize),
            iv.heightAnchor.constraint(equalToConstant: iconSize),
            iconWrap.widthAnchor.constraint(equalToConstant: 28),
            iconWrap.heightAnchor.constraint(equalToConstant: 28)
        ])

        // Labels
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.text = value
        // Dört ana metrik (Süre, Mesafe, Tempo, Kalori) için ortak, biraz daha ince font
        valueLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        valueLabel.textColor = .label

        let labels = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        labels.axis = .vertical
        labels.spacing = 4

        // Inner horizontal content (icon + labels)
        let inner = UIStackView(arrangedSubviews: [iconWrap, labels])
        inner.axis = .horizontal
        inner.alignment = .center
        inner.spacing = 12
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        inner.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])

        // Wrap card so it behaves nicely in the 2x2 grid
        let wrapper = UIStackView(arrangedSubviews: [card])
        wrapper.axis = .vertical
        wrapper.alignment = .fill
        return wrapper
    }

    private func makeStepsCard(steps: Int) -> UIStackView {
        let card = UIView()
        card.backgroundColor = .tertiarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        // Icon badge
        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = .secondarySystemBackground
        iconWrap.layer.cornerRadius = 14

        let iv = UIImageView(image: UIImage(systemName: "figure.walk"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor(hex: "#006BFF")

        iconWrap.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            iv.widthAnchor.constraint(equalToConstant: 16),
            iv.heightAnchor.constraint(equalToConstant: 16),
            iconWrap.widthAnchor.constraint(equalToConstant: 28),
            iconWrap.heightAnchor.constraint(equalToConstant: 28)
        ])

        // Labels: başlık solda, adım sayısı en sağda
        let titleLabel = UILabel()
        titleLabel.text = "Adım"
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.text = "\(steps)"
        valueLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .right

        let spacer = UIView()

        let inner = UIStackView(arrangedSubviews: [iconWrap, titleLabel, spacer, valueLabel])
        inner.axis = .horizontal
        inner.alignment = .center
        inner.spacing = 8
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        inner.translatesAutoresizingMaskIntoConstraints = false

        // Hugging/compression: ikon+başlık solda, adım sayısı sağda kalsın
        iconWrap.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])

        let wrapper = UIStackView(arrangedSubviews: [card])
        wrapper.axis = .vertical
        wrapper.alignment = .fill
        return wrapper
    }
}
