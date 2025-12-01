import UIKit // UIKit framework'ünü içe aktarır
import MapKit // Harita ve konum işlemleri için MapKit'i içe aktarır
import CoreLocation // Konum servisleri için CoreLocation'u içe aktarır

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

    let startButton: UIButton = { // Koşuyu başlat/durdur butonu
        let b = UIButton(type: .system) // Sistem tipi buton oluşturur
        b.setTitle("Koşuyu Başlat", for: .normal) // Buton başlığını ayarlar
        b.titleLabel?.font = .boldSystemFont(ofSize: 18) // Başlık fontunu ayarlar
        b.backgroundColor = UIColor(hex: "#006BFF")   // Trackly mavisi // Arka plan rengini ayarlar
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

        // Konum servisleri açık mı?
        guard CLLocationManager.locationServicesEnabled() else { // Konum servisleri kapalıysa
            showLocationServicesDisabledAlert() // Uyarı gösterir
            return // Fonksiyondan çıkar
        }

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
            startButton.setTitle("Durdur", for: .normal) // Buton başlığını değiştirir
            routeCoords.removeAll() // Rota koordinatlarını temizler
            if let poly = routePolyline { // Eğer rota çizgisi varsa
                mapView.removeOverlay(poly) // Haritadan kaldırır
                routePolyline = nil // Referansı sıfırlar
            }
            totalDistanceMeters = 0 // Toplam mesafeyi sıfırlar
            lastCoordinate = nil // Son koordinatı sıfırlar
            runStartDate = Date() // Koşu başlangıç zamanını ayarlar

            runTimer?.invalidate() // Önceki timer varsa iptal eder
            runTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in // Her saniye metrikleri güncelleyen timer
                self?.updateMetrics() // Metrikleri günceller
            }

            // Konum güncellemelerini garantiye al
            if CLLocationManager.locationServicesEnabled() { // Konum servisleri açıksa
                let st = currentAuthStatus() // İzin durumunu alır
                if st == .authorizedWhenInUse || st == .authorizedAlways { // İzin verilmişse
                    locationManager.startUpdatingLocation() // Konum güncellemelerini başlatır
                }
            }
        } else { // Koşu durduruluyorsa
            // Durdur
            startButton.setTitle("Koşuyu Başlat", for: .normal) // Buton başlığını değiştirir
            runTimer?.invalidate() // Timer'ı iptal eder
            runTimer = nil // Timer referansını sıfırlar

            // Final metrikler
            let elapsed = currentElapsedSeconds() // Geçen süreyi alır
            let km = totalDistanceMeters / 1000.0 // Mesafeyi kilometreye çevirir
            let kcal = km * userWeightKg * kcalPerKmPerKg // Kalori hesaplar

            // İsim iste
            let ask = UIAlertController( // Koşuya isim verme uyarısı oluşturur
                title: "Koşunu Adlandır", // Başlık
                message: "Serüven listesinde bu ad ile görünecek.", // Mesaj
                preferredStyle: .alert // Stil alert
            )
            ask.addTextField { $0.placeholder = "Örn: Sahil Koşusu" } // TextField ekler
            ask.addAction(UIAlertAction(title: "Vazgeç", style: .cancel, handler: nil)) // Vazgeç butonu
            ask.addAction(UIAlertAction(title: "Kaydet", style: .default, handler: { [weak self] _ in // Kaydet butonu aksiyonu
                guard let self = self else { return } // Self'i güçlü referansa çevirir
                let nameInput = ask.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) // Girilen ismi alır
                let name = (nameInput?.isEmpty == false) ? nameInput! : // Eğer boş değilse kullanır
                    DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short) // Boşsa tarih bazlı isim oluşturur

                let run = Run( // Yeni Run nesnesi oluşturur
                    name: name, // İsim
                    date: Date(), // Tarih
                    durationSeconds: elapsed, // Süre
                    distanceMeters: self.totalDistanceMeters, // Mesafe
                    calories: kcal, // Kalori
                    route: self.routeCoords // Rota koordinatları
                )
                RunStore.shared.add(run) // Koşuyu kaydeder

                let msg = String( // Kaydetme mesajı hazırlar
                    format: "Kaydedildi • %.2f km • %@", // Format
                    run.distanceKm, // Mesafe
                    self.formatPace(secondsPerKm: run.avgPaceSecPerKm) // Ortalama tempo
                )
                let done = UIAlertController( // Kaydedildi uyarısı oluşturur
                    title: "Koşu Kaydedildi", // Başlık
                    message: msg, // Mesaj
                    preferredStyle: .alert // Stil alert
                )
                done.addAction(UIAlertAction(title: "Kapat", style: .cancel, handler: nil)) // Kapat butonu ekler
                self.present(done, animated: true, completion: nil) // Uyarıyı gösterir
            }))
            present(ask, animated: true, completion: nil) // İsim verme uyarısını gösterir
        }
    }
}
