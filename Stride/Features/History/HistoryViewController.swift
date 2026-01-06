//
//  HistoryViewController.swift
//  Stride
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

import SwiftUI
#Preview {
    ViewControllerPreview {
        HistoryViewController()
    }
}

final class HistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate { // History ekranı, tablo görünümü veri kaynağı ve delegesi

    // MARK: - UI
    let tableView = UITableView(frame: .zero, style: .insetGrouped) // Tablo görünümü, sıfır çerçeve ve insetGrouped stili
    let periodControl: UISegmentedControl = { // Periyot seçim kontrolü
        let sc = UISegmentedControl(items: ["Hafta", "Ay", "Yıl"]) // Segmentler: Hafta, Ay, Yıl
        sc.selectedSegmentIndex = 0 // İlk segment seçili
        return sc // Kontrolü döndür
    }()
    let rangeHeader = UIStackView() // Aralık başlığı için yığın görünümü
    let prevButton = UIButton(type: .system) // Önceki aralık butonu
    let nextButton = UIButton(type: .system) // Sonraki aralık butonu
    let rangeLabel = UILabel() // Aralık bilgisi etiketi

    // MARK: - State
    enum Period: Int { // History ekranı için periyot türü
        case week = 0
        case month
        case year
    }

    var periodOffset: Int = 0 // Seçilen periyot kaydırması
    var currentPeriod: Period = .week // Geçerli periyot, varsayılan hafta
    var data: [Run] = [] // Koşu verileri dizisi

    // MARK: - Lifecycle
    override func viewDidLoad() { // Görünüm yüklendiğinde çağrılır
        super.viewDidLoad() // Üst sınıfın viewDidLoad çağrısı
        view.backgroundColor = .systemBackground // Arka plan rengini sistem arka planı yap

        applyBrandTitle() // Başlık stilini uygula
        setupControls() // Kontrolleri hazırla
        setupTableView() // Tablo görünümünü hazırla
        reloadData() // Verileri yeniden yükle (Firestore tarafı +Data dosyasında)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleDistanceUnitChanged),
                                               name: .strideDistanceUnitDidChange,
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) { // Görünüm ekranda görünmeden önce çağrılır
        super.viewWillAppear(animated) // Üst sınıfın viewWillAppear çağrısı
        reloadData() // Verileri yeniden yükle
    }

    // MARK: - Actions
    @objc func periodChanged() { // Periyot segmenti değiştiğinde
        let idx = periodControl.selectedSegmentIndex // Seçili segment indeksi
        currentPeriod = Period(rawValue: idx) ?? .week // Geçerli periyodu güncelle
        periodOffset = 0 // Kaydırmayı sıfırla
        reloadData() // Verileri yeniden yükle
    }

    @objc func prevRange() { // Önceki aralığa geç
        periodOffset -= 1 // Kaydırmayı azalt
        reloadData() // Verileri yeniden yükle
    }

    @objc func nextRange() { // Sonraki aralığa geç
        periodOffset += 1 // Kaydırmayı artır
        reloadData() // Verileri yeniden yükle
    }

    @objc private func handleDistanceUnitChanged() {
        // Refresh visible text (km/mi) without refetching
        tableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { // Tablo satır sayısı
        data.count // Veri sayısını döndür
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell { // Satır hücresi oluşturma

        let run = data[indexPath.row] // İlgili koşuyu al
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) // Yeniden kullanılabilir hücre al
        var conf = cell.defaultContentConfiguration() // Hücre içerik konfigürasyonu oluştur

        // Sadece koşu ismi
        conf.text = run.name // Koşu adını ayarla
        conf.textProperties.font = .systemFont(ofSize: 16, weight: .semibold) // Yazı tipini ayarla
        conf.textProperties.color = .label // Yazı rengini ayarla
        conf.secondaryText = formattedRunSubtitle(run: run) // km/mi + opsiyonel süre
        conf.secondaryTextProperties.font = .systemFont(ofSize: 13, weight: .regular)
        conf.secondaryTextProperties.color = .secondaryLabel

        // Solda koşu ikonu (stride mavisi)
        conf.image = UIImage(systemName: "figure.run") // Koşu simgesi ayarla
        conf.imageProperties.tintColor = UIColor(hex: "#006BFF") // Simge rengini mavi yap
        conf.imageProperties.preferredSymbolConfiguration =
            UIImage.SymbolConfiguration(pointSize: 18, weight: .medium) // Simge boyut ve ağırlığını ayarla

        cell.contentConfiguration = conf // Hücre içeriğini ata
        cell.accessoryType = .disclosureIndicator // Sağ ok göstergesi ekle
        return cell // Hücreyi döndür
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) { // Satır seçildiğinde
        tableView.deselectRow(at: indexPath, animated: true) // Seçimi kaldır
        let run = data[indexPath.row] // Seçilen koşuyu al
        let vc = RunDetailViewController(run: run) // Detay ekranını oluştur
        navigationController?.pushViewController(vc, animated: true) // Detay ekranına geç
    }

    // Silme (Swipe to delete)
    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) { // Satır düzenleme işlemi
        if editingStyle == .delete { // Silme işlemi ise
            let run = data[indexPath.row] // Silinecek koşuyu al

            // Firestore'dan sil
            #if canImport(FirebaseAuth)
            guard Auth.auth().currentUser != nil else {
                let ac = UIAlertController(title: "Giriş gerekli", message: "Silmek için giriş yapmalısın.", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "Tamam", style: .default))
                present(ac, animated: true)
                return
            }
            #endif

            RunFirestoreStore.shared.deleteRun(runId: run.id) { [weak self] err in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let err = err {
                        let ac = UIAlertController(title: "Silinemedi", message: err.localizedDescription, preferredStyle: .alert)
                        ac.addAction(UIAlertAction(title: "Tamam", style: .default))
                        self.present(ac, animated: true)
                        return
                    }
                    self.data.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            }
        }
    }

    // MARK: - Distance Unit Formatting

    private enum DistanceUnit {
        case kilometers
        case miles
    }

    private func currentDistanceUnit() -> DistanceUnit {
        let raw = UserDefaults.standard.string(forKey: "stride.distanceUnit") ?? "kilometers"
        return (raw == "miles") ? .miles : .kilometers
    }

    private func formattedRunSubtitle(run: Run) -> String? {
        // Try to extract meters and seconds from the Run model without hard dependencies
        let meters = extractNumeric(from: run, keys: [
            "distanceMeters", "distance_m", "distanceInMeters", "distance", "meters"
        ])

        let seconds = extractNumeric(from: run, keys: [
            "durationSeconds", "duration_s", "durationInSeconds", "duration", "seconds"
        ])

        guard let meters = meters, meters > 0 else {
            // If we can't find distance, keep it minimal (no subtitle)
            return nil
        }

        let unit = currentDistanceUnit()
        let distanceText: String
        switch unit {
        case .kilometers:
            distanceText = String(format: "%.2f km", meters / 1000.0)
        case .miles:
            distanceText = String(format: "%.2f mi", meters / 1609.344)
        }

        if let seconds = seconds, seconds > 0 {
            return "\(distanceText) • \(formatDuration(seconds: seconds))"
        } else {
            return distanceText
        }
    }

    private func extractNumeric(from run: Run, keys: [String]) -> Double? {
        let mirror = Mirror(reflecting: run)
        for child in mirror.children {
            guard let label = child.label else { continue }
            guard keys.contains(label) else { continue }

            if let v = child.value as? Double { return v }
            if let v = child.value as? Float { return Double(v) }
            if let v = child.value as? Int { return Double(v) }
            if let v = child.value as? Int64 { return Double(v) }
            if let v = child.value as? UInt { return Double(v) }
            if let v = child.value as? UInt64 { return Double(v) }
        }

        return nil
    }

    private func formatDuration(seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
