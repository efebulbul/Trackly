//
//  RunDetailViewController.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır
import MapKit // Harita ve konum hizmetleri için MapKit framework'ünü içe aktarır

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

final class RunDetailViewController: UIViewController { // Koşu detaylarını gösterecek ViewController sınıfı

    let run: Run // Görüntülenecek koşu verisi
    let map = MKMapView() // Koşu rotasını gösterecek harita görünümü
    let stack = UIStackView() // Genel düzen için stack view

    var durRow: UIStackView! // Süre satırı için stack view
    var distRow: UIStackView! // Mesafe satırı için stack view
    var paceRow: UIStackView! // Tempo satırı için stack view
    var kcalRow: UIStackView! // Kalori satırı için stack view

    var leftCol: UIStackView! // Sol sütun için stack view
    var rightCol: UIStackView! // Sağ sütun için stack view
    var metricsGrid: UIStackView! // Metriklerin ızgara düzeni için stack view

    // MARK: - Init
    init(run: Run) { // Koşu verisi ile başlatıcı
        self.run = run // Parametre olarak gelen koşuyu property'ye atar
        super.init(nibName: nil, bundle: nil) // Üst sınıf initializer çağrısı
    }
    required init?(coder: NSCoder) { fatalError() } // Storyboard kullanımı desteklenmez

    // MARK: - Lifecycle
    override func viewDidLoad() { // View yüklendiğinde çağrılır
        super.viewDidLoad() // Üst sınıfın viewDidLoad metodunu çağırır
        title = run.name // Navigation bar başlığı koşu adı olarak ayarlanır
        view.backgroundColor = .systemBackground // Arka plan rengi sistem arka planı yapılır

        navigationItem.rightBarButtonItem = UIBarButtonItem( // Sağ üstte silme butonu oluşturur
            title: "Sil", // Buton başlığı "Sil"
            style: .plain, // Düz stil
            target: self, // Hedef self (bu view controller)
            action: #selector(deleteRun) // Butona basıldığında deleteRun fonksiyonunu çağırır
        )

        setupLayout() // Arayüz düzenini kurar
        refreshAllMetricTexts()
        drawRoute() // Koşu rotasını harita üzerinde çizer

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleDistanceUnitChanged),
                                               name: .tracklyDistanceUnitDidChange,
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAllMetricTexts()
    }

    // MARK: - Actions
    @objc func deleteRun() { // Koşuyu silme işlemi için fonksiyon
        let alert = UIAlertController( // Silme onayı için uyarı oluşturur
            title: "Koşuyu Sil", // Uyarı başlığı
            message: "Bu koşuyu silmek istediğine emin misin?", // Uyarı mesajı
            preferredStyle: .alert // Uyarı stili
        )
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel, handler: nil)) // İptal butonu ekler
        alert.addAction(UIAlertAction(title: "Sil", style: .destructive, handler: { _ in // Sil butonu ekler
#if canImport(FirebaseAuth)
guard Auth.auth().currentUser != nil else {
    let ac = UIAlertController(title: "Giriş gerekli", message: "Devam etmek için giriş yap.", preferredStyle: .alert)
    ac.addAction(UIAlertAction(title: "Tamam", style: .default))
    self.present(ac, animated: true)
    return
}

// Firestore'dan sil
RunFirestoreStore.shared.deleteRun(runId: self.run.id) { [weak self] err in
    DispatchQueue.main.async {
        guard let self = self else { return }
        if let err = err {
            let ac = UIAlertController(title: "Silinemedi", message: err.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "Tamam", style: .default))
            self.present(ac, animated: true)
            return
        }
        self.navigationController?.popViewController(animated: true)
    }
}
#endif
        }))
        present(alert, animated: true, completion: nil) // Uyarıyı ekranda gösterir
    }

    // MARK: - Unit helpers (km / mi)

    private func isMilesSelected() -> Bool {
        let raw = UserDefaults.standard.string(forKey: "trackly.distanceUnit") ?? "kilometers"
        return raw == "miles"
    }

    private func runDistanceMeters() -> Double {
        // Prefer strongly-typed properties if they exist, otherwise fallback to reflection.
        let mirror = Mirror(reflecting: run)
        for child in mirror.children {
            guard let label = child.label else { continue }
            if ["distanceMeters", "distanceInMeters", "meters", "distance"].contains(label) {
                if let v = child.value as? Double { return v }
                if let v = child.value as? Float { return Double(v) }
                if let v = child.value as? Int { return Double(v) }
                if let v = child.value as? Int64 { return Double(v) }
            }
        }
        return 0
    }

    private func runDurationSeconds() -> Double {
        let mirror = Mirror(reflecting: run)
        for child in mirror.children {
            guard let label = child.label else { continue }
            if ["durationSeconds", "durationInSeconds", "seconds", "duration"].contains(label) {
                if let v = child.value as? Double { return v }
                if let v = child.value as? Float { return Double(v) }
                if let v = child.value as? Int { return Double(v) }
                if let v = child.value as? Int64 { return Double(v) }
            }
        }
        return 0
    }

    private func runCalories() -> Double {
        let mirror = Mirror(reflecting: run)
        for child in mirror.children {
            guard let label = child.label else { continue }
            if ["kcal", "calories", "activeCalories", "energyKcal"].contains(label) {
                if let v = child.value as? Double { return v }
                if let v = child.value as? Float { return Double(v) }
                if let v = child.value as? Int { return Double(v) }
                if let v = child.value as? Int64 { return Double(v) }
            }
        }
        return 0
    }

    private func durationText() -> String {
        let seconds = runDurationSeconds()
        guard seconds > 0 else { return "--" }
        return hms(Int(seconds.rounded()))
    }

    private func kcalText() -> String {
        let kcal = runCalories()
        guard kcal > 0 else { return "--" }
        return String(format: "%.0f kcal", kcal)
    }

    private func distanceTextForCurrentUnit() -> String {
        let meters = runDistanceMeters()
        if isMilesSelected() {
            return String(format: "%.2f mi", meters / 1609.344)
        } else {
            return String(format: "%.2f km", meters / 1000.0)
        }
    }

    private func paceTextForCurrentUnit() -> String {
        let meters = runDistanceMeters()
        let seconds = runDurationSeconds()
        guard meters > 0, seconds > 0 else {
            return "--"
        }

        let distancePerUnit: Double
        let suffix: String

        if isMilesSelected() {
            distancePerUnit = meters / 1609.344
            suffix = "/mi"
        } else {
            distancePerUnit = meters / 1000.0
            suffix = "/km"
        }

        guard distancePerUnit > 0 else { return "--" }
        let secPerUnit = seconds / distancePerUnit
        let m = Int(secPerUnit) / 60
        let s = Int(secPerUnit) % 60
        return String(format: "%d:%02d %@", m, s, suffix)
    }

    private func refreshAllMetricTexts() {
        // Update the metric value labels (expected layout: [titleLabel, valueLabel])
        updateValueLabel(in: durRow, with: durationText())
        updateValueLabel(in: distRow, with: distanceTextForCurrentUnit())
        updateValueLabel(in: paceRow, with: paceTextForCurrentUnit())
        updateValueLabel(in: kcalRow, with: kcalText())
    }

    private func updateValueLabel(in row: UIStackView?, with text: String) {
        guard let row = row else { return }
        let labels = row.arrangedSubviews.compactMap { $0 as? UILabel }
        // Expected layout: [titleLabel, valueLabel]
        if labels.count >= 2 {
            labels[1].text = text
        }
    }

    // MARK: - Formatting
    func hms(_ seconds: Int) -> String { // Saniyeyi saat:dakika:saniye formatına çevirir
        let h = seconds / 3600 // Saat hesaplama
        let m = (seconds % 3600) / 60 // Dakika hesaplama
        let s = seconds % 60 // Saniye hesaplama
        return String(format: "%01d:%02d:%02d", h, m, s) // Formatlanmış string döner
    }

    @objc private func handleDistanceUnitChanged() {
        // Update only displayed texts (no need to redraw map)
        refreshAllMetricTexts()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
