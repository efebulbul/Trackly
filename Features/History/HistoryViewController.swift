//
//  HistoryViewController.swift
//  Trackly
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
        conf.secondaryText = nil // İkincil metni kaldır

        // Solda koşu ikonu (Trackly mavisi)
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
}
