//
//  RunViewController.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır
import MapKit // Harita ve konum işlemleri için MapKit'i içe aktarır
import CoreLocation // Konum servisleri için CoreLocation'u içe aktarır
import CoreMotion // Adım sayacı (pedometer) için CoreMotion'u içe aktarır

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
    let stepsValue = UILabel() // Adım sayısını gösteren label
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
    // Adım tahmini: ~1300 adım / km (ortalama)
    let stepsPerKm: Double = 1300 // Adım sayısı tahmini

    // MARK: - Pedometer
    let pedometer = CMPedometer()          // Cihazın adım sayacını kullanmak için
    var pedometerSteps: Int = 0            // Koşu süresince atılan gerçek adım sayısı

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
        distValue.text = "0.00 km" // Mesafe label'ını sıfırlar
        kcalValue.text = "0" // Kalori label'ını sıfırlar
        stepsValue.text = "0" // Adım label'ını sıfırlar
        paceValue.text = "0:00 /km" // Tempo label'ını sıfırlar

        startButton.addTarget(self, action: #selector(startRunTapped), for: .touchUpInside) // Butona tıklama aksiyonu ekler
        updateMetrics() // Metrikleri günceller
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

            // Adım sayaçlarını sıfırla
            pedometerSteps = 0

            // Pedometer başlat (gerçek adım verisi)
            if CMPedometer.isStepCountingAvailable() {
                let startDate = runStartDate ?? Date()
                pedometer.startUpdates(from: startDate) { [weak self] data, error in
                    guard let self = self, let data = data, error == nil else { return }
                    DispatchQueue.main.async {
                        self.pedometerSteps = data.numberOfSteps.intValue
                    }
                }
            }

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

            // Pedometer durdur
            pedometer.stopUpdates()

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

                RunFirestoreStore.shared.addRun(run, steps: self.pedometerSteps) { [weak self] err in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if let err = err {
                            let ac = UIAlertController(title: "Kaydedilemedi", message: err.localizedDescription, preferredStyle: .alert)
                            ac.addAction(UIAlertAction(title: "Tamam", style: .default))
                            self.present(ac, animated: true)
                            return
                        }

                        // başarı UI'ı
                        let msg = String(
                            format: "Kaydedildi • %.2f km • %@",
                            run.distanceKm,
                            self.formatPace(secondsPerKm: run.avgPaceSecPerKm)
                        )
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
}
