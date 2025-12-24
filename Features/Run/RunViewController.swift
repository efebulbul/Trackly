//
//  RunViewController.swift
//  Trackly
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
        b.setTitle("Koşuyu Başlat", for: .normal) // Buton başlığını ayarlar
        b.titleLabel?.font = .boldSystemFont(ofSize: 18) // Başlık fontunu ayarlar
        b.backgroundColor = .appBlue   // Trackly mavisi // Arka plan rengini ayarlar
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

        // Varsayılan metinler
        timeValue.text = "0:00:00" // Zaman label'ını sıfırlar
        distValue.text = "--"
        kcalValue.text = "0" // Kalori label'ını sıfırlar
        paceValue.text = "--"

        startButton.addTarget(self, action: #selector(startRunTapped), for: .touchUpInside) // Butona tıklama aksiyonu ekler
        updateMetrics() // Metrikleri günceller

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDistanceUnitChanged),
            name: .tracklyDistanceUnitDidChange,
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
    @objc func startRunTapped() { // Koşuyu başlat/durdur butonuna tıklanınca
        isRunning.toggle() // Koşu durumunu değiştirir

        if isRunning { // Koşu başlatılıyorsa
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
            let st = currentAuthStatus()
            if st == .authorizedWhenInUse || st == .authorizedAlways {
                locationManager.startUpdatingLocation()
            } else if st == .denied || st == .restricted {
                showLocationDeniedAlert()
            }
        } else { // Koşu durduruluyorsa
            // Durdur
            startButton.setTitle("Koşuyu Başlat", for: .normal)
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
                        let unitRaw = UserDefaults.standard.string(forKey: "trackly.distanceUnit") ?? "kilometers"
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
