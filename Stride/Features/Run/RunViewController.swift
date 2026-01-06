//
//  RunViewController.swift
//  Stride
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır
import MapKit // Harita ve konum işlemleri için MapKit'i içe aktarır
import CoreLocation // Konum servisleri için CoreLocation'u içe aktarır

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

import SwiftUI
#Preview {
    ViewControllerPreview {
        RunViewController()
    }
}

final class RunViewController: UIViewController { // Koşu ekranını yöneten view controller

    // MARK: - UI
    let mapView = MKMapView() // Harita görünümü oluşturur
    let bottomPanel = UIView() // Alt panel görünümü oluşturur
    let contentStack = UIStackView()          // panel içi dikey stack

    let timeValue = UILabel() // Zaman değerini gösteren label
    let distValue = UILabel() // Mesafe değerini gösteren label
    let kcalValue = UILabel() // Kalori değerini gösteren label
    let paceValue = UILabel() // Tempo değerini gösteren label

    // MARK: - Konum
    let locationManager = CLLocationManager() // Konum yöneticisi oluşturur
    var hasCenteredOnUser = false // Kullanıcıya odaklanılıp odaklanılmadığını tutar
    var askedAlwaysOnce = false // Sürekli konum izni sorulup sorulmadığını tutar

    // MARK: - Rota
    var isRunning = false // Koşunun aktif olup olmadığını tutar
    var routeCoords: [CLLocationCoordinate2D] = [] // Koşu rotası koordinatları
    var routePolyline: MKPolyline? // Harita üzerinde rota çizgisi

    // MARK: - Run metrics
    var runTimer: Timer? // Koşu zamanlayıcısı
    var runStartDate: Date? // Koşunun başlangıç zamanı
    var totalDistanceMeters: Double = 0 // Toplam mesafe metre cinsinden
    var lastCoordinate: CLLocationCoordinate2D? // Son konum koordinatı
    var userWeightKg: Double = 70 // kcal ≈ 1.036 * kg * km
    // Kalori kalibrasyonu
    let kcalPerKmPerKg: Double = 1.036 / 1.5 // Kalori hesaplama katsayısı

    let startButton: UIButton = { // Koşuyu başlat/durdur butonu
        let b = UIButton(type: .system) // Sistem tipi buton oluşturur
        b.setTitle("BAŞLAT", for: .normal) // Strava benzeri kısa CTA
        b.titleLabel?.font = .boldSystemFont(ofSize: 18) // Başlık fontunu ayarlar
        b.backgroundColor = .appBlue   // stride mavisi // Arka plan rengini ayarlar
        b.tintColor = .white // Başlık rengini beyaz yapar
        b.layer.cornerRadius = 28 // Köşe yuvarlama uygular
        b.heightAnchor.constraint(equalToConstant: 56).isActive = true // Yükseklik kısıtlaması
        return b // Butonu döndürür
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() { // View yüklendiğinde çağrılır
        super.viewDidLoad() // Üst sınıfın viewDidLoad metodunu çağırır
        title = "Koşu" // Navigation bar başlığını ayarlar
        view.backgroundColor = .systemBackground // Arka plan rengini sistem arka planı yapar

        // Konum yöneticisi kurulumu
        locationManager.delegate = self // Konum yöneticisi delegesini ayarlar
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // En iyi konum doğruluğunu talep eder
        locationManager.distanceFilter = 5 // Konum güncelleme mesafe filtresi (5 metre)
        locationManager.allowsBackgroundLocationUpdates = true // Arka planda konum güncellemesine izin verir
        if #available(iOS 11.0, *) { // iOS 11 ve sonrası için
            locationManager.showsBackgroundLocationIndicator = true // Arka planda konum göstergesini aktif eder
        }

        setupMap() // Harita görünümünü hazırlar
        mapView.delegate = self // Harita delegesini ayarlar
        setupBottomPanel() // Alt panel UI öğelerini hazırlar
        layoutConstraints() // Auto Layout kısıtlamalarını uygular
        addTrackingButton() // Haritaya takip butonu ekler

        // Varsayılan metinler (Strava düzeni: Sol=Zaman, Orta=Tempo, Sağ=Mesafe)
        timeValue.text = "00:00:00"
        paceValue.text = "--:-- /km"
        distValue.text = "0.00"
        kcalValue.text = "0"

        startButton.addTarget(self, action: #selector(startRunTapped), for: .touchUpInside) // Butona tıklama aksiyonu ekler
        updateMetrics() // Metrikleri günceller

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDistanceUnitChanged),
            name: .strideDistanceUnitDidChange,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) { // View ekranda göründüğünde çağrılır
        super.viewDidAppear(animated) // Üst sınıfın metodunu çağırır

        let status = currentAuthStatus() // Şu anki konum izin durumunu alır
        if status == .notDetermined { // Eğer izin durumu belirlenmemişse
            DispatchQueue.main.async { // Ana thread'de
                self.locationManager.requestWhenInUseAuthorization() // Kullanım sırasında konum izni ister
            }
        } else if status == .authorizedWhenInUse || status == .authorizedAlways { // Eğer izin verilmişse
            mapView.showsUserLocation = true // Haritada kullanıcı konumunu göster
            locationManager.startUpdatingLocation() // Konum güncellemelerini başlat
            locationManager.requestLocation() // Anlık konum iste
        }
    }

    // MARK: - Actions
    @objc func showFullMetrics() {
        let vc = FullMetricsViewController(source: self)
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    @objc func startRunTapped() { // Koşuyu başlat/durdur butonuna tıklanınca
        isRunning.toggle() // Koşu durumunu değiştirir

        if isRunning { // Koşu başlatılıyorsa
            // Başlat: UI & veri temizliği
            startButton.setTitle("DURAKLAT", for: .normal)
            routeCoords.removeAll()
            if let poly = routePolyline {
                mapView.removeOverlay(poly)
                routePolyline = nil
            }
            totalDistanceMeters = 0
            lastCoordinate = nil
            runStartDate = Date()

            // UI reset
            timeValue.text = "00:00:00"
            paceValue.text = "--:-- /km"
            distValue.text = "0.00"
            kcalValue.text = "0"

            runTimer?.invalidate()
            runTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateMetrics()
            }

            // Konum güncellemelerini garantiye al
            let st = currentAuthStatus()
            if st == .authorizedWhenInUse || st == .authorizedAlways {
                locationManager.startUpdatingLocation()
            } else if st == .denied || st == .restricted {
                showLocationDeniedAlert()
            }
        } else { // Koşu durduruluyorsa
            // Durdur
            startButton.setTitle("BAŞLAT", for: .normal)
            runTimer?.invalidate()
            runTimer = nil

            // Final metrikler
            let elapsed = currentElapsedSeconds()
            let km = totalDistanceMeters / 1000.0
            let kcal = km * userWeightKg * kcalPerKmPerKg

            let ask = UIAlertController(
                title: "Koşunu Adlandır",
                message: "Serüven listesinde bu ad ile görünecek.",
                preferredStyle: .alert
            )
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

                // ✅ Login zorunlu: FirebaseAuth yoksa/bağlı değilse devam ettirmeyelim
                #if canImport(FirebaseAuth)
                guard Auth.auth().currentUser != nil else {
                    let ac = UIAlertController(title: "Giriş gerekli", message: "Devam etmek için giriş yap.", preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "Tamam", style: .default))
                    self.present(ac, animated: true)
                    return
                }
                #else
                let ac = UIAlertController(title: "Firebase eksik", message: "FirebaseAuth hedefe ekli değil. Lütfen FirebaseAuth'u projeye ekleyip tekrar dene.", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "Tamam", style: .default))
                self.present(ac, animated: true)
                return
                #endif

                // ✅ Step sayar kaldırıldı: store'a steps:0 gönderiyoruz (Firestore tarafında alan opsiyonel olabilir)
                RunFirestoreStore.shared.addRun(run, steps: 0) { [weak self] err in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if let err = err {
                            let ac = UIAlertController(title: "Kaydedilemedi", message: err.localizedDescription, preferredStyle: .alert)
                            ac.addAction(UIAlertAction(title: "Tamam", style: .default))
                            self.present(ac, animated: true)
                            return
                        }

                        // başarı UI'ı
                        let unitRaw = UserDefaults.standard.string(forKey: "stride.distanceUnit") ?? "kilometers"
                        let isMiles = (unitRaw == "miles")
                        let distanceText: String
                        let paceText: String

                        if isMiles {
                            distanceText = String(format: "%.2f mi", run.distanceMeters / 1609.344)
                            let secPerMi = run.avgPaceSecPerKm * (1000.0 / 1609.344)
                            let m = Int(secPerMi) / 60
                            let s = Int(secPerMi) % 60
                            paceText = String(format: "%d:%02d /mi", m, s)
                        } else {
                            distanceText = String(format: "%.2f km", run.distanceMeters / 1000.0)
                            paceText = self.formatPace(secondsPerKm: run.avgPaceSecPerKm)
                        }

                        let msg = "Kaydedildi • \(distanceText) • \(paceText)"
                        let done = UIAlertController(
                            title: "Koşu Kaydedildi",
                            message: msg,
                            preferredStyle: .alert
                        )
                        done.addAction(UIAlertAction(title: "Kapat", style: .cancel, handler: nil))
                        self.present(done, animated: true, completion: nil)
                    }
                }
            }))
            present(ask, animated: true, completion: nil)
        }
    }

    @objc private func handleDistanceUnitChanged() {
        updateMetrics()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Strava-like Full Metrics Overlay
final class FullMetricsViewController: UIViewController {

    private weak var source: RunViewController?
    private var timer: Timer?

    private let statusLabel = UILabel()
    private let timeLabel = UILabel()
    private let paceValueLabel = UILabel()
    private let paceTitleLabel = UILabel()
    private let distValueLabel = UILabel()
    private let distTitleLabel = UILabel()
    private let kcalValueLabel = UILabel()
    private let kcalTitleLabel = UILabel()

    init(source: RunViewController) {
        self.source = source
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)

        // Dim + blur panel
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 18
        blur.clipsToBounds = true
        view.addSubview(blur)

        // Close / collapse button (top-right)
        let closeBtn = UIButton(type: .system)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setImage(UIImage(systemName: "arrow.down.right.and.arrow.up.left"), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        blur.contentView.addSubview(closeBtn)

        // Labels styling
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor = UIColor.systemGreen
        statusLabel.textAlignment = .center

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 44, weight: .bold)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .center

        paceValueLabel.translatesAutoresizingMaskIntoConstraints = false
        paceValueLabel.font = .monospacedDigitSystemFont(ofSize: 48, weight: .bold)
        paceValueLabel.textColor = .white
        paceValueLabel.textAlignment = .center
        paceValueLabel.adjustsFontSizeToFitWidth = true
        paceValueLabel.minimumScaleFactor = 0.6

        paceTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        paceTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        paceTitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        paceTitleLabel.textAlignment = .center

        distValueLabel.translatesAutoresizingMaskIntoConstraints = false
        distValueLabel.font = .monospacedDigitSystemFont(ofSize: 56, weight: .bold)
        distValueLabel.textColor = .white
        distValueLabel.textAlignment = .center
        distValueLabel.adjustsFontSizeToFitWidth = true
        distValueLabel.minimumScaleFactor = 0.6

        distTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        distTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        distTitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        distTitleLabel.textAlignment = .center

        kcalValueLabel.translatesAutoresizingMaskIntoConstraints = false
        kcalValueLabel.font = .monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        kcalValueLabel.textColor = .white
        kcalValueLabel.textAlignment = .center

        kcalTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        kcalTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        kcalTitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        kcalTitleLabel.textAlignment = .center

        // Layout stack
        let stack = UIStackView(arrangedSubviews: [
            statusLabel,
            timeLabel,
            UIView(),
            paceValueLabel,
            paceTitleLabel,
            UIView(),
            distValueLabel,
            distTitleLabel,
            UIView(),
            kcalValueLabel,
            kcalTitleLabel
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        blur.contentView.addSubview(stack)

        // Give spacers height
        (stack.arrangedSubviews[2] as? UIView)?.heightAnchor.constraint(equalToConstant: 18).isActive = true
        (stack.arrangedSubviews[5] as? UIView)?.heightAnchor.constraint(equalToConstant: 22).isActive = true
        (stack.arrangedSubviews[8] as? UIView)?.heightAnchor.constraint(equalToConstant: 18).isActive = true

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            blur.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            blur.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            closeBtn.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 14),
            closeBtn.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -14),
            closeBtn.widthAnchor.constraint(equalToConstant: 34),
            closeBtn.heightAnchor.constraint(equalToConstant: 34),

            stack.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor)
        ])

        // Subtle app signature (imza)
        let signatureLabel = UILabel()
        signatureLabel.translatesAutoresizingMaskIntoConstraints = false
        signatureLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        signatureLabel.textAlignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .kern: 1.6,
            .foregroundColor: UIColor.appBlue.withAlphaComponent(0.55)
        ]
        signatureLabel.attributedText = NSAttributedString(string: "Stride", attributes: attrs)

        blur.contentView.addSubview(signatureLabel)

        NSLayoutConstraint.activate([
            signatureLabel.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            signatureLabel.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -14)
        ])

        refreshTexts()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshTexts()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func refreshTexts() {
        guard let src = source else { return }

        // GPS status (simple)
        statusLabel.text = src.mapView.showsUserLocation ? "GPS Acquired" : "GPS" 

        timeLabel.text = src.timeValue.text ?? "00:00:00"

        // Pace value + unit subtitle (use existing text if already formatted)
        let paceText = src.paceValue.text ?? "--:-- /km"
        paceValueLabel.text = paceText
        paceTitleLabel.text = "Avg. pace"

        // Distance
        let unitRaw = UserDefaults.standard.string(forKey: "stride.distanceUnit") ?? "kilometers"
        let unit = (unitRaw == "miles") ? "mi" : "km"
        distValueLabel.text = src.distValue.text ?? "0.00"
        distTitleLabel.text = "Distance (\(unit))"

        // Calories
        kcalValueLabel.text = src.kcalValue.text ?? "0"
        kcalTitleLabel.text = "Calories"
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
