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
        drawRoute() // Koşu rotasını harita üzerinde çizer
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
// ✅ Login zorunlu olduğundan burada user nil beklemiyoruz
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

    // MARK: - Formatting
    func hms(_ seconds: Int) -> String { // Saniyeyi saat:dakika:saniye formatına çevirir
        let h = seconds / 3600 // Saat hesaplama
        let m = (seconds % 3600) / 60 // Dakika hesaplama
        let s = seconds % 60 // Saniye hesaplama
        return String(format: "%01d:%02d:%02d", h, m, s) // Formatlanmış string döner
    }

    func paceText(_ secPerKm: Double) -> String { // Km başına saniye cinsinden tempoyu metne çevirir
        guard secPerKm.isFinite, secPerKm > 0 else { return "0:00 /km" } // Geçerli değilse varsayılan döner
        let m = Int(secPerKm) / 60 // Dakika kısmı
        let s = Int(secPerKm) % 60 // Saniye kısmı
        return String(format: "%d:%02d /km", m, s) // Formatlanmış tempo metni döner
    }
}
