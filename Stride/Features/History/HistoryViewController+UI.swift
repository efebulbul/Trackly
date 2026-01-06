//
//  HistoryViewController+UI.swift
//  Stride
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır

extension HistoryViewController { // HistoryViewController için extension başlatır

    // MARK: - UI Setup
    func setupControls() { // Kontrolleri kuran fonksiyon
        periodControl.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları kapatır
        view.addSubview(periodControl) // periodControl'ü view'a ekler

        // Üstte tarih aralığı navigasyonu (haftalar/aylar/yıllar arası geçiş)
        rangeHeader.axis = .horizontal // Yönü yatay yapar
        rangeHeader.alignment = .center // Hizalamayı ortalar
        rangeHeader.distribution = .equalCentering // Eşit aralıkla dağıtır
        rangeHeader.spacing = 12 // Elemanlar arası boşluk 12pt
        rangeHeader.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları kapatır

        prevButton.setImage(UIImage(systemName: "chevron.left"), for: .normal) // Sol ok simgesi ayarlar
        prevButton.addTarget(self, action: #selector(prevRange), for: .touchUpInside) // Önceki aralık aksiyonu ekler

        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal) // Sağ ok simgesi ayarlar
        nextButton.addTarget(self, action: #selector(nextRange), for: .touchUpInside) // Sonraki aralık aksiyonu ekler

        rangeLabel.font = .systemFont(ofSize: 16, weight: .semibold) // Yazı tipini ve ağırlığını ayarlar
        rangeLabel.textColor = .label // Yazı rengini sistem renk yapar
        rangeLabel.textAlignment = .center // Yazıyı ortalar
        rangeLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal) // Yatayda sıkıştırılmaya karşı öncelik verir

        rangeHeader.addArrangedSubview(prevButton) // Önceki butonunu stack'e ekler
        rangeHeader.addArrangedSubview(rangeLabel) // Aralık etiketini stack'e ekler
        rangeHeader.addArrangedSubview(nextButton) // Sonraki butonunu stack'e ekler

        prevButton.setContentHuggingPriority(.required, for: .horizontal) // Önceki butonun sıkıştırılma önceliği
        nextButton.setContentHuggingPriority(.required, for: .horizontal) // Sonraki butonun sıkıştırılma önceliği
        prevButton.widthAnchor.constraint(equalTo: nextButton.widthAnchor).isActive = true // Buton genişliklerini eşitler
        rangeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) // Etiketin sıkıştırılma direncini düşürür

        view.addSubview(rangeHeader) // rangeHeader'ı view'a ekler

        NSLayoutConstraint.activate([ // Kısıtlamaları aktif eder
            rangeHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8), // Üstten 8pt boşluk
            rangeHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32), // Soldan 32pt boşluk
            rangeHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32), // Sağdan 32pt boşluk

            periodControl.topAnchor.constraint(equalTo: rangeHeader.bottomAnchor, constant: 8), // periodControl üstü 8pt boşluk
            periodControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16), // Soldan 16pt boşluk
            periodControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16) // Sağdan 16pt boşluk
        ])

        // Segment değişimi
        periodControl.addTarget(self, action: #selector(periodChanged), for: .valueChanged) // Segment değişim aksiyonu ekler
    }

    func setupTableView() { // Tablo görünümünü kuran fonksiyon
        tableView.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları kapatır
        tableView.dataSource = self // Veri kaynağını atar
        tableView.delegate = self // Delegesini atar
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell") // Hücre kaydeder
        view.addSubview(tableView) // tableView'ı view'a ekler

        NSLayoutConstraint.activate([ // Kısıtlamaları aktif eder
            tableView.topAnchor.constraint(equalTo: periodControl.bottomAnchor, constant: 8), // Üstten 8pt boşluk
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor), // Soldan sıfır boşluk
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor), // Sağdan sıfır boşluk
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor) // Alttan sıfır boşluk
        ])
    }

    // Empty-state background
    func applyEmptyState() { // Boş durum arka planını uygular
        let label = UILabel() // Yeni UILabel oluşturur
        label.text = "Bu dönemde koşu yok" // Etiket metni
        label.textColor = .secondaryLabel // İkincil etiket rengi
        label.textAlignment = .center // Yazıyı ortalar
        label.numberOfLines = 0 // Çok satırlı olabilir
        label.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları kapatır

        let container = UIView() // Konteyner görünüm oluşturur
        container.addSubview(label) // Etiketi konteynere ekler

        NSLayoutConstraint.activate([ // Kısıtlamaları aktif eder
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor), // X ekseninde ortalar
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor), // Y ekseninde ortalar
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 20), // Soldan en az 20pt boşluk
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20) // Sağdan en az 20pt boşluk
        ])

        tableView.backgroundView = container // tableView arka planını konteyner yapar
    }

    // MARK: - Branded Title
    func applyBrandTitle() { // Marka başlığını uygular
        let label = UILabel()
        label.textAlignment = .center

        let title = NSMutableAttributedString(
            string: "Stride",
            attributes: [
                .foregroundColor: UIColor.label,
                .font: UIFont.boldSystemFont(ofSize: 30)
            ]
        )

        title.append(NSAttributedString(
            string: "X",
            attributes: [
                .foregroundColor: UIColor.appBlue,
                .font: UIFont.boldSystemFont(ofSize: 30)
            ]
        ))

        label.attributedText = title
        navigationItem.titleView = label
    }
}
