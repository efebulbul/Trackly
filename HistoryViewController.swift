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
        title = "Serüven"
        view.backgroundColor = .systemBackground

        navigationItem.titleView = periodControl
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
        tableView.reloadData()
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

final class RunDetailViewController: UIViewController, MKMapViewDelegate {
    private let run: Run
    private let map = MKMapView()
    private let stack = UIStackView()
    private var durRow: UIStackView!
    private var distRow: UIStackView!
    private var paceRow: UIStackView!
    private var kcalRow: UIStackView!

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

        durRow  = labelRow(title: "Süre",   value: hms(run.durationSeconds))
        distRow = labelRow(title: "Mesafe", value: String(format: "%.2f km", run.distanceKm))
        paceRow = labelRow(title: "Tempo",  value: paceText(run.avgPaceSecPerKm))
        kcalRow = labelRow(title: "Kalori", value: String(Int(run.calories.rounded())))
        
        // Uzun basınca gizle/göster menüsü
        addHideGesture(to: durRow,  key: "stat_duration")
        addHideGesture(to: distRow, key: "stat_distance")
        addHideGesture(to: paceRow, key: "stat_pace")
        addHideGesture(to: kcalRow, key: "stat_calories")
        
        stack.addArrangedSubview(durRow)
        stack.addArrangedSubview(distRow)
        stack.addArrangedSubview(paceRow)
        stack.addArrangedSubview(kcalRow)

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

        applyHiddenStates()
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
    
    // Uzun basınca istatistik gizle/göster
    private func addHideGesture(to view: UIView, key: String) {
        view.isUserInteractionEnabled = true
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        lp.minimumPressDuration = 0.5
        view.addGestureRecognizer(lp)
        view.accessibilityIdentifier = key
    }
    
    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began, let v = gr.view, let key = v.accessibilityIdentifier else { return }
        let isHidden = isStatHidden(key)
        let title = isHidden ? "Göster" : "Gizle"
        let alert = UIAlertController(title: "İstatistik", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
            self.setStatHidden(key, hidden: !isHidden)
            self.applyHiddenStates()
        }))
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel))
        present(alert, animated: true)
    }
    
    private func isStatHidden(_ key: String) -> Bool {
        UserDefaults.standard.bool(forKey: key)
    }
    
    private func setStatHidden(_ key: String, hidden: Bool) {
        UserDefaults.standard.set(hidden, forKey: key)
    }
    
    private func applyHiddenStates() {
        durRow.isHidden  = isStatHidden("stat_duration")
        distRow.isHidden = isStatHidden("stat_distance")
        paceRow.isHidden = isStatHidden("stat_pace")
        kcalRow.isHidden = isStatHidden("stat_calories")
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
}
