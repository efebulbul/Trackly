import UIKit
import MapKit

final class HistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let periodControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Gün", "Hafta", "Ay", "Yıl", "Tümü"])
        sc.selectedSegmentIndex = 0
        return sc
    }()
    private var currentPeriod: RunStore.Period = .day
    private var data: [Run] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Üst başlık: Trackly (ly mavi)
        applyBrandTitle()

        // Dönem değişimi (UI'da göstermiyoruz ama filtre mantığı korunuyor)
        periodControl.addTarget(self, action: #selector(periodChanged), for: .valueChanged)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
        let all: [RunStore.Period] = [.day, .week, .month, .year, .all]
        currentPeriod = all[idx]
        reloadData()
    }

    private func reloadData() {
        data = RunStore.shared.filteredRuns(for: currentPeriod)
        // Üstte özet/header GÖSTERME
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

        conf.text = run.name

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        let km = run.distanceKm
        let paceMin = Int(run.avgPaceSecPerKm) / 60
        let paceSec = Int(run.avgPaceSecPerKm) % 60
        conf.secondaryText = String(format: "%@ • %.2f km • %d:%02d /km",
                                    df.string(from: run.date), km, paceMin, paceSec)
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
        distRow = makeMetricCard(title: "Mesafe", value: String(format: "%.2f km", run.distanceKm), icon: "map")
        paceRow = makeMetricCard(title: "Tempo",  value: paceText(run.avgPaceSecPerKm), icon: "speedometer")
        kcalRow = makeMetricCard(title: "Kalori", value: String(Int(run.calories.rounded())), icon: "flame")
    
        leftCol = UIStackView(arrangedSubviews: [durRow, kcalRow])
        leftCol.axis = .vertical
        leftCol.spacing = 12
    
        rightCol = UIStackView(arrangedSubviews: [distRow, paceRow])
        rightCol.axis = .vertical
        rightCol.spacing = 12
    
        metricsGrid = UIStackView(arrangedSubviews: [leftCol, rightCol])
        metricsGrid.axis = .horizontal
        metricsGrid.distribution = .fillEqually
        metricsGrid.alignment = .fill
        metricsGrid.spacing = 12
        metricsGrid.translatesAutoresizingMaskIntoConstraints = false
    
        // Increase spacing for aesthetics
        stack.spacing = 16
        stack.addArrangedSubview(metricsGrid)

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
        let card = UIView()
        card.backgroundColor = .tertiarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = .secondarySystemBackground
        iconWrap.layer.cornerRadius = 18

        let iv = UIImageView(image: UIImage(systemName: icon))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor(hex: "#006BFF")

        iconWrap.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            iv.widthAnchor.constraint(equalToConstant: 18),
            iv.heightAnchor.constraint(equalToConstant: 18),
            iconWrap.widthAnchor.constraint(equalToConstant: 36),
            iconWrap.heightAnchor.constraint(equalToConstant: 36)
        ])

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 20, weight: .bold)
        valueLabel.textColor = .label

        let labels = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        labels.axis = .vertical
        labels.spacing = 2

        let inner = UIStackView(arrangedSubviews: [iconWrap, labels])
        inner.axis = .horizontal
        inner.alignment = .center
        inner.spacing = 10
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        inner.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])

        let wrapper = UIStackView(arrangedSubviews: [card])
        wrapper.axis = .vertical
        wrapper.alignment = .fill
        return wrapper
    }
}
