import UIKit
import MapKit
import CoreLocation

// HEX → UIColor
extension UIColor {
    convenience init(hex: String) {
        var c = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if c.hasPrefix("#") { c.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: c).scanHexInt64(&rgb)
        self.init(
            red:   CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8)  / 255.0,
            blue:  CGFloat( rgb & 0x0000FF)        / 255.0,
            alpha: 1.0
        )
    }
}

final class RunViewController: UIViewController, CLLocationManagerDelegate {

    // MARK: - UI
    private let mapView = MKMapView()
    private let bottomPanel = UIView()
    private let contentStack = UIStackView()          // panel içi dikey stack
    private let gridStack = UIStackView()             // 2x2 kart alanı (yatay)

    private let timeValue = UILabel()
    private let distValue = UILabel()
    private let kcalValue = UILabel()
    private let paceValue = UILabel()
    private var trackingButton: MKUserTrackingButton!
    private let locationManager = CLLocationManager()
    private var hasCenteredOnUser = false
    private var askedAlwaysOnce = false

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

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Koşu"
        view.backgroundColor = .systemBackground

        setupMap()
        setupBottomPanel()
        layoutConstraints()
        addTrackingButton()

        // Konum yöneticisi
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        if #available(iOS 11.0, *) { }

        // Varsayılan metinler
        timeValue.text = "0:00:00"
        distValue.text = "0.00 km"
        kcalValue.text = "0"
        paceValue.text = "0:00 /km"

        startButton.addTarget(self, action: #selector(startRunTapped), for: .touchUpInside)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Konum servisleri kapalıysa uyar
        guard CLLocationManager.locationServicesEnabled() else {
            showLocationServicesDisabledAlert()
            return
        }
        let status = currentAuthStatus()
        if status == .notDetermined {
            // İlk kez: izin penceresini aç
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            // Yetki zaten varsa, konumu başlat ve hızlıca bir konum iste
            mapView.showsUserLocation = true
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        }
        // .denied / .restricted durumlarını delegate içinde zaten ele alıyoruz
        #if DEBUG
        if Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") == nil {
            print("⚠️ Missing Info.plist key: NSLocationWhenInUseUsageDescription")
        }
        #endif
    }

    // MARK: - Setup
    private func setupMap() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.showsCompass = true
        mapView.showsScale = false
        mapView.pointOfInterestFilter = .includingAll
        mapView.showsUserLocation = true
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
        bottomPanel.layer.cornerRadius = 24
        bottomPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
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

        // Grid (yatay)
        gridStack.axis = .horizontal
        gridStack.alignment = .fill
        gridStack.distribution = .fillEqually
        gridStack.spacing = 12

        // Sütunlar
        let leftCol = UIStackView(); leftCol.axis = .vertical; leftCol.spacing = 12
        let rightCol = UIStackView(); rightCol.axis = .vertical; rightCol.spacing = 12

        // 4 kart
        leftCol.addArrangedSubview(makeMetricCard(title: "Toplam Süre", valueLabel: timeValue))
        rightCol.addArrangedSubview(makeMetricCard(title: "Mesafe", valueLabel: distValue))
        leftCol.addArrangedSubview(makeMetricCard(title: "Kalori", valueLabel: kcalValue))
        rightCol.addArrangedSubview(makeMetricCard(title: "TEMPO", valueLabel: paceValue))

        gridStack.addArrangedSubview(leftCol)
        gridStack.addArrangedSubview(rightCol)

        // Stack’e ekle (grid + buton)
        contentStack.addArrangedSubview(gridStack)
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
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
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
        let btn = MKUserTrackingButton(mapView: mapView)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.layer.cornerRadius = 8
        btn.backgroundColor = .secondarySystemBackground
        view.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            btn.widthAnchor.constraint(equalToConstant: 40),
            btn.heightAnchor.constraint(equalToConstant: 40)
        ])
        trackingButton = btn
    }

    // MARK: - Permission Flow
    private func currentAuthStatus() -> CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return locationManager.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }


    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            manager.startUpdatingLocation()
            mapView.showsUserLocation = true
            if let coord = manager.location?.coordinate, !hasCenteredOnUser {
                let region = MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800)
                mapView.setRegion(region, animated: true)
                hasCenteredOnUser = true
            }
        case .authorizedWhenInUse:
            if !askedAlwaysOnce {
                askedAlwaysOnce = true
                manager.requestAlwaysAuthorization()
            }
            manager.startUpdatingLocation()
            mapView.showsUserLocation = true
            if let coord = manager.location?.coordinate, !hasCenteredOnUser {
                let region = MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800)
                mapView.setRegion(region, animated: true)
                hasCenteredOnUser = true
            }
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
        if !hasCenteredOnUser {
            let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
            mapView.setRegion(region, animated: true)
            hasCenteredOnUser = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
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

    // MARK: - Actions
    @objc private func startRunTapped() {
        print("Run started")
    }
}
