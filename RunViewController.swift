import UIKit //Ekranı, tasarımı, butonu oluşturma.
import MapKit //Harita üzerinde çizim, rota.
import CoreLocation //GPS konum almak için.

// HEX → UIColor
extension UIColor { //UIColor’a yeni özellik ekiyorum
    convenience init(hex: String) { //HEX ile renk oluşturmanı sağlar
        var c = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() //Renk kodunu temizler
        if c.hasPrefix("#") { c.removeFirst() } //Başındaki # işaretini siler
        var rgb: UInt64 = 0
        Scanner(string: c).scanHexInt64(&rgb) ///HEX string → sayı
        self.init(
            red:   CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8)  / 255.0,
            blue:  CGFloat( rgb & 0x0000FF)        / 255.0,
            alpha: 1.0
        )
    }

}

// MARK: - Run Model & Storage (with name)

struct Coord: Codable, Hashable {
    let lat: Double
    let lon: Double
    init(_ c: CLLocationCoordinate2D) {
        self.lat = c.latitude
        self.lon = c.longitude
    }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct Run: Codable, Hashable {
    let id: UUID
    let name: String
    let date: Date
    let durationSeconds: Int
    let distanceMeters: Double
    let calories: Double
    let route: [Coord]
    
    init(name: String, date: Date, durationSeconds: Int, distanceMeters: Double, calories: Double, route: [CLLocationCoordinate2D]) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.calories = calories
        self.route = route.map { Coord($0) }
    }
    
    var distanceKm: Double { distanceMeters / 1000.0 }
    var avgPaceSecPerKm: Double { distanceKm > 0 ? Double(durationSeconds) / distanceKm : 0 }
}

final class RunStore {
    static let shared = RunStore()
    private init() { load() }
    
    private(set) var runs: [Run] = []
    
    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("runs.json")
    }
    
    func add(_ run: Run) {
        runs.append(run)
        runs.sort { $0.date > $1.date }
        save()
    }

    func delete(id: UUID) {
        runs.removeAll { $0.id == id }
        save()
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(runs)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("RunStore save error:", error)
        }
    }
    
    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Run].self, from: data)
            self.runs = decoded.sorted { $0.date > $1.date }
        } catch {
            self.runs = []
        }
    }
    
    enum Period: Int, CaseIterable { case day, week, month, year, all }
    
    func filteredRuns(for period: Period, reference: Date = Date()) -> [Run] {
        switch period {
        case .day:
            let start = Calendar.current.startOfDay(for: reference)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            return runs.filter { ($0.date >= start) && ($0.date < end) }
        case .week:
            let cal = Calendar.current
            let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: reference))!
            let end = cal.date(byAdding: .day, value: 7, to: start)!
            return runs.filter { ($0.date >= start) && ($0.date < end) }
        case .month:
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: reference)
            let start = cal.date(from: comps)!
            let end = cal.date(byAdding: .month, value: 1, to: start)!
            return runs.filter { ($0.date >= start) && ($0.date < end) }
        case .year:
            let cal = Calendar.current
            let comps = cal.dateComponents([.year], from: reference)
            let start = cal.date(from: comps)!
            let end = cal.date(byAdding: .year, value: 1, to: start)!
            return runs.filter { ($0.date >= start) && ($0.date < end) }
        case .all:
            return runs
        }
    }
}

final class RunViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    // MARK: - UI
    private let mapView = MKMapView()
    private let bottomPanel = UIView()
    private let contentStack = UIStackView()          // panel içi dikey stack

    private let timeValue = UILabel()
    private let distValue = UILabel()
    private let kcalValue = UILabel()
    private let stepsValue = UILabel()
    private let paceValue = UILabel()

    // Konum
    private let locationManager = CLLocationManager()
    private var hasCenteredOnUser = false
    private var askedAlwaysOnce = false

    // Rota
    private var isRunning = false
    private var routeCoords: [CLLocationCoordinate2D] = []
    private var routePolyline: MKPolyline?

    // Run metrics
    private var runTimer: Timer?
    private var runStartDate: Date?
    private var totalDistanceMeters: Double = 0
    private var lastCoordinate: CLLocationCoordinate2D?
    private var userWeightKg: Double = 70 // kcal ≈ 1.036 * kg * km
    // Calorie formula calibration (previously overestimated ~1.5x)
    private let kcalPerKmPerKg: Double = 1.036 / 1.5
    // Adım tahmini: ~1300 adım / km (ortalama)
    private let stepsPerKm: Double = 1300

    private let startButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Koşuyu Başlat", for: .normal)
        b.titleLabel?.font = .boldSystemFont(ofSize: 18)
        b.backgroundColor = UIColor(hex: "#006BFF")   // ✅ MAVİ
        b.tintColor = .white
        b.layer.cornerRadius = 28
        b.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return b
    }()

    // MARK: - Formatting helpers
    private func formatHMS(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%01d:%02d:%02d", h, m, s)
    }
    private func formatPace(secondsPerKm: Double) -> String {
        guard secondsPerKm.isFinite, secondsPerKm > 0 else { return "0:00 /km" }
        let m = Int(secondsPerKm) / 60
        let s = Int(secondsPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }

    // MARK: - Info.plist safety helpers
    private func hasPlistKey(_ key: String) -> Bool {
        return Bundle.main.object(forInfoDictionaryKey: key) != nil
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Koşu"
        view.backgroundColor = .systemBackground

        // Konum yöneticisi kurulumu
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.allowsBackgroundLocationUpdates = true
        if #available(iOS 11.0, *) {
            locationManager.showsBackgroundLocationIndicator = true
        }

        setupMap()
        mapView.delegate = self
        setupBottomPanel()
        layoutConstraints()
        addTrackingButton()

        // Varsayılan metinler
        timeValue.text = "0:00:00"
        distValue.text = "0.00 km"
        kcalValue.text = "0"
        stepsValue.text = "0"
        paceValue.text = "0:00 /km"

        startButton.addTarget(self, action: #selector(startRunTapped), for: .touchUpInside)
        updateMetrics()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Konum servisleri açık mı?
        guard CLLocationManager.locationServicesEnabled() else {
            showLocationServicesDisabledAlert()
            return
        }
        // İlk kez: izin diyalogu
        let status = currentAuthStatus()
        if status == .notDetermined {
            DispatchQueue.main.async {
                self.locationManager.requestWhenInUseAuthorization()
            }
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            mapView.showsUserLocation = true
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        }
    }

    // MARK: - Permission Flow
    private func currentAuthStatus() -> CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return locationManager.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }

    private func showLocationServicesDisabledAlert() {
        let alert = UIAlertController(
            title: "Konum Servisleri Kapalı",
            message: "Koşu takibi için Konum Servisleri açık olmalı. Ayarlar > Gizlilik ve Güvenlik > Konum Servisleri'ni aç.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Ayarlar", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    private func showLocationDeniedAlert() {
        let alert = UIAlertController(
            title: "Konum İzni Gerekli",
            message: "Koşu takibi için konum erişimine izin vermen gerekiyor. Ayarlar'dan izin verebilirsin.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Ayarlar", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Setup
    private func setupMap() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.pointOfInterestFilter = .includingAll
        mapView.preferredConfiguration = MKStandardMapConfiguration(
            elevationStyle: .realistic,
            emphasisStyle: .muted
        )
        view.addSubview(mapView)
    }

    private func setupBottomPanel() {
        // Panel
        bottomPanel.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.backgroundColor = .secondarySystemBackground
        bottomPanel.layer.cornerRadius = 0
        view.addSubview(bottomPanel)

        // İç dikey stack
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        contentStack.spacing = 12
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.addSubview(contentStack)

        // Yatay kaydırılabilir metrik şerit (chip tarzı)
        let metricsScroll = UIScrollView()
        metricsScroll.showsHorizontalScrollIndicator = false
        metricsScroll.translatesAutoresizingMaskIntoConstraints = false
        
        let metricsRow = UIStackView()
        metricsRow.axis = .horizontal
        metricsRow.alignment = .fill
        metricsRow.distribution = .fill
        metricsRow.spacing = 12
        metricsRow.translatesAutoresizingMaskIntoConstraints = false
        
        metricsScroll.addSubview(metricsRow)
        // Scroll içerik pinleri
        NSLayoutConstraint.activate([
            metricsRow.topAnchor.constraint(equalTo: metricsScroll.contentLayoutGuide.topAnchor),
            metricsRow.leadingAnchor.constraint(equalTo: metricsScroll.contentLayoutGuide.leadingAnchor),
            metricsRow.trailingAnchor.constraint(equalTo: metricsScroll.contentLayoutGuide.trailingAnchor),
            metricsRow.bottomAnchor.constraint(equalTo: metricsScroll.contentLayoutGuide.bottomAnchor),
            metricsRow.heightAnchor.constraint(equalTo: metricsScroll.frameLayoutGuide.heightAnchor)
        ])
        
        // 5 adet chip ekle (hepsi aynı genişlikte)
        let timeChip  = makeMetricChip(title: "Toplam Süre", valueLabel: timeValue, systemName: "timer")
        let distChip  = makeMetricChip(title: "Mesafe",      valueLabel: distValue, systemName: "map")
        let paceChip  = makeMetricChip(title: "Tempo",       valueLabel: paceValue, systemName: "speedometer")
        let kcalChip  = makeMetricChip(title: "Kalori",      valueLabel: kcalValue, systemName: "flame")
        let stepsChip = makeMetricChip(title: "Adım",        valueLabel: stepsValue, systemName: "figure.walk")

        metricsRow.addArrangedSubview(timeChip)
        metricsRow.addArrangedSubview(distChip)
        metricsRow.addArrangedSubview(paceChip)
        metricsRow.addArrangedSubview(kcalChip)
        metricsRow.addArrangedSubview(stepsChip)

        // Tüm chip'ler aynı genişlikte olsun, Kalori eskisi gibi geniş kalsın, Adım da yanına aynı genişlikte gelsin
        let chips = [timeChip, distChip, paceChip, kcalChip, stepsChip]
        if let baseChip = chips.first {
            chips.forEach { chip in
                chip.widthAnchor.constraint(equalTo: baseChip.widthAnchor).isActive = true
            }
        }
        
        // İçeriği ana dikey stack'e ekle (önce scroll, sonra buton)
        contentStack.addArrangedSubview(metricsScroll)
        contentStack.addArrangedSubview(startButton)
    }

    private func layoutConstraints() {
        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // Map üstte, panelin üstüne kadar
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Panel alt sabitleme
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12),
            bottomPanel.topAnchor.constraint(greaterThanOrEqualTo: safe.centerYAnchor), // opsiyonel sınır

            // Map ile panel arasında boşluk yok
            mapView.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor),

            // Panel iç stack
            contentStack.topAnchor.constraint(equalTo: bottomPanel.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomPanel.bottomAnchor),
        ])
    }

    private func addTrackingButton() {
        // Tracking button (merkezleme butonu)
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.layer.cornerRadius = 8
        btn.backgroundColor = .secondarySystemBackground

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let image = UIImage(systemName: "location.fill", withConfiguration: config)
        btn.setImage(image, for: .normal)
        btn.tintColor = UIColor(hex: "#006BFF")

        btn.addTarget(self, action: #selector(centerOnUserTapped), for: .touchUpInside)

        view.addSubview(btn)

        // Compass button (pusula)
        let compass = MKCompassButton(mapView: mapView)
        compass.translatesAutoresizingMaskIntoConstraints = false
        compass.compassVisibility = .visible

        view.addSubview(compass)

        NSLayoutConstraint.activate([
            // Compass en üstte, sağda
            compass.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            compass.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            compass.widthAnchor.constraint(equalToConstant: 40),
            compass.heightAnchor.constraint(equalToConstant: 40),

            // Tracking butonu pusulanın hemen altında
            btn.topAnchor.constraint(equalTo: compass.bottomAnchor, constant: 8),
            btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            btn.widthAnchor.constraint(equalToConstant: 40),
            btn.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    @objc private func centerOnUserTapped() {
        guard let coord = mapView.userLocation.location?.coordinate else { return }
        let region = MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800)
        mapView.setRegion(region, animated: true)
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            // When-In-Use alındı → Always iste (bir kez ve Info.plist anahtarı varsa)
            if !askedAlwaysOnce {
                askedAlwaysOnce = true
                if hasPlistKey("NSLocationAlwaysAndWhenInUseUsageDescription") {
                    manager.requestAlwaysAuthorization()
                }
            }
            mapView.showsUserLocation = true
            manager.startUpdatingLocation()
        case .authorizedAlways:
            mapView.showsUserLocation = true
            manager.startUpdatingLocation()
        case .denied, .restricted:
            showLocationDeniedAlert()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        // Zayıf doğruluk verilerini at (accuracy > 20m veya negatif)
        if loc.horizontalAccuracy < 0 || loc.horizontalAccuracy > 20 {
            return
        }
        if !hasCenteredOnUser {
            let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
            mapView.setRegion(region, animated: true)
            hasCenteredOnUser = true
        }

        // Mesafe biriktirme
        if isRunning {
            let current = loc
            if let last = lastCoordinate {
                let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
                let delta = current.distance(from: lastLoc) // meters
                // Gürültü filtreleri: min 5m adım, 30m üzeri sıçramaları at
                if delta >= 5 && delta <= 30 {
                    totalDistanceMeters += delta
                }
            }
            lastCoordinate = current.coordinate
        }

        // Çizim: koşu aktifken yeni noktayı hatta ekle
        if isRunning, let last = locations.last {
            appendCoordinate(last.coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }

    // Rota noktasını ekle ve overlay'i güncelle
    private func appendCoordinate(_ coord: CLLocationCoordinate2D) {
        // Gürültüyü azalt: son noktaya çok yakınsa ekleme (5 m eşiği)
        if let last = routeCoords.last {
            let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let newLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if newLoc.distance(from: lastLoc) < 5 { return }
        }
        routeCoords.append(coord)
        updateRouteOverlay()
    }

    private func updateRouteOverlay() {
        if let poly = routePolyline {
            mapView.removeOverlay(poly)
        }
        let polyline = MKPolyline(coordinates: routeCoords, count: routeCoords.count)
        routePolyline = polyline
        mapView.addOverlay(polyline)
    }

    // MARK: - Metrics
    private func updateMetrics() {
        // Süre
        let elapsed: Int
        if let start = runStartDate, isRunning {
            elapsed = Int(Date().timeIntervalSince(start))
        } else if let start = runStartDate {
            elapsed = Int(Date().timeIntervalSince(start))
        } else {
            elapsed = 0
        }
        timeValue.text = formatHMS(elapsed)
        
        // Mesafe (km)
        let km = totalDistanceMeters / 1000.0
        distValue.text = String(format: "%.2f km", km)
        
        // Tempo (ortalama pace)
        let paceSecPerKm = km > 0 ? Double(elapsed) / km : 0
        paceValue.text = formatPace(secondsPerKm: paceSecPerKm)
        
        // Kalori (yaklaşık): 1.036 * kg * km (calibrated)
        let kcal = km * userWeightKg * kcalPerKmPerKg
        kcalValue.text = String(Int(kcal.rounded()))
        
        // Adım sayısı (yaklaşık): km * stepsPerKm
        let steps = Int((km * stepsPerKm).rounded())
        stepsValue.text = "\(steps)"
    }


    // MARK: - Helpers
    private func makeMetricCard(title: String, valueLabel: UILabel) -> UIView {
        let card = UIView()
        card.backgroundColor = .tertiarySystemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        // minimum yükseklik
        let h = card.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        h.priority = .required
        h.isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .secondaryLabel

        valueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let v = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        v.axis = .vertical
        v.spacing = 4
        v.isLayoutMarginsRelativeArrangement = true
        v.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        v.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: card.topAnchor),
            v.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            v.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    private func makeMetricChip(title: String, valueLabel: UILabel, systemName: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .tertiarySystemBackground
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Sol ikon (daire arkaplan)
        let iconWrap = UIView()
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.backgroundColor = .secondarySystemBackground
        iconWrap.layer.cornerRadius = 18
        
        let icon = UIImageView(image: UIImage(systemName: systemName))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .label
        
        iconWrap.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            iconWrap.widthAnchor.constraint(equalToConstant: 36),
            iconWrap.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // Metinler
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        
        valueLabel.font = .systemFont(ofSize: 20, weight: .bold)
        valueLabel.textColor = .label
        
        let labels = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        labels.axis = .vertical
        labels.spacing = 2
        
        // Yatay içerik
        let h = UIStackView(arrangedSubviews: [iconWrap, labels])
        h.axis = .horizontal
        h.alignment = .center
        h.spacing = 10
        h.isLayoutMarginsRelativeArrangement = true
        h.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        h.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(h)
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: container.topAnchor),
            h.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            h.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            h.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
        return container
    }

    // MARK: - Actions
    @objc private func startRunTapped() {
        isRunning.toggle()
        if isRunning {
            // Başlat: UI & veri temizliği
            startButton.setTitle("Durdur", for: .normal)
            routeCoords.removeAll()
            if let poly = routePolyline {
                mapView.removeOverlay(poly)
                routePolyline = nil
            }
            totalDistanceMeters = 0
            lastCoordinate = nil
            runStartDate = Date()
            runTimer?.invalidate()
            runTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateMetrics()
            }
            // Konum güncellemelerini garantiye al
            if CLLocationManager.locationServicesEnabled() {
                let st = currentAuthStatus()
                if st == .authorizedWhenInUse || st == .authorizedAlways {
                    locationManager.startUpdatingLocation()
                }
            }
        } else {
            // Durdur
            startButton.setTitle("Koşuyu Başlat", for: .normal)
            runTimer?.invalidate()
            runTimer = nil
            
            // Final metrikler
            let elapsed: Int = (runStartDate != nil) ? Int(Date().timeIntervalSince(runStartDate!)) : 0
            let km = totalDistanceMeters / 1000.0
            let kcal = km * userWeightKg * kcalPerKmPerKg
            
            // İsim iste
            let ask = UIAlertController(title: "Koşunu Adlandır", message: "Serüven listesinde bu ad ile görünecek.", preferredStyle: .alert)
            ask.addTextField { $0.placeholder = "Örn: Sahil Koşusu" }
            ask.addAction(UIAlertAction(title: "Vazgeç", style: .cancel, handler: nil))
            ask.addAction(UIAlertAction(title: "Kaydet", style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                let nameInput = ask.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = (nameInput?.isEmpty == false) ? nameInput! :
                           DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
                
                let run = Run(
                    name: name,
                    date: Date(),
                    durationSeconds: elapsed,
                    distanceMeters: self.totalDistanceMeters,
                    calories: kcal,
                    route: self.routeCoords
                )
                RunStore.shared.add(run)
                
                // Bilgi & Serüven'e git
                let msg = String(format: "Kaydedildi • %.2f km • %@", run.distanceKm, self.formatPace(secondsPerKm: run.avgPaceSecPerKm))
                let done = UIAlertController(title: "Koşu Kaydedildi", message: msg, preferredStyle: .alert)
                done.addAction(UIAlertAction(title: "Kapat", style: .cancel, handler: nil))
                self.present(done, animated: true, completion: nil)
            }))
            present(ask, animated: true, completion: nil)
        }
    }

    // MARK: - MKMapViewDelegate
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let r = MKPolylineRenderer(polyline: polyline)
            r.strokeColor = UIColor(hex: "#006BFF")
            r.lineWidth = 8
            r.lineJoin = .round
            r.lineCap = .round
            r.alpha = 0.95
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}


