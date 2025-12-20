//
//  RunDetailViewController+UI.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır

extension RunDetailViewController { // RunDetailViewController için extension başlatılır

    func setupLayout() { // Layout kurulum fonksiyonu tanımlanır
        map.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır
        map.delegate = self // Harita delegesi atanır
        view.addSubview(map) // Harita görünümü ana görünüme eklenir

        stack.axis = .vertical // Stack dikey eksende hizalanır
        stack.spacing = 16   // biraz nefes alan layout
        stack.isLayoutMarginsRelativeArrangement = true // Layout marginlere göre düzenleme yapılır
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16) // Stack içerik kenar boşlukları ayarlanır
        stack.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır

        // 2x2 symmetric metric grid (cards)
        durRow  = makeMetricCard( // Süre kartı oluşturulur
            title: "Süre", // Kart başlığı
            value: hms(run.durationSeconds), // Süre değeri formatlanır
            icon: "timer" // Kart ikonu
        )
        distRow = makeMetricCard( // Mesafe kartı oluşturulur
            title: "Mesafe", // Kart başlığı
            value: String(format: "%.2f km", run.distanceKm), // Mesafe değeri formatlanır
            icon: "map" // Kart ikonu
        )
        paceRow = makeMetricCard( // Tempo kartı oluşturulur
            title: "Tempo", // Kart başlığı
            value: paceText(run.avgPaceSecPerKm), // Tempo değeri formatlanır
            icon: "speedometer" // Kart ikonu
        )
        kcalRow = makeMetricCard( // Kalori kartı oluşturulur
            title: "Kalori", // Kart başlığı
            value: String(Int(run.calories.rounded())), // Kalori değeri yuvarlanır ve stringe çevrilir
            icon: "flame.fill" // Kart ikonu
        )

        leftCol = UIStackView(arrangedSubviews: [durRow, kcalRow]) // Sol sütun stack'i oluşturulur
        leftCol.axis = .vertical // Sol sütun dikey hizalanır
        leftCol.spacing = 16 // Sol sütun elemanları arası boşluk ayarlanır

        rightCol = UIStackView(arrangedSubviews: [distRow, paceRow]) // Sağ sütun stack'i oluşturulur
        rightCol.axis = .vertical // Sağ sütun dikey hizalanır
        rightCol.spacing = 16 // Sağ sütun elemanları arası boşluk ayarlanır

        metricsGrid = UIStackView(arrangedSubviews: [leftCol, rightCol]) // Sol ve sağ sütunlar yatay stack'te birleştirilir
        metricsGrid.axis = .horizontal // Grid yatay hizalanır
        metricsGrid.distribution = .fillEqually // Elemanlar eşit genişlikte dağıtılır
        metricsGrid.alignment = .fill // Elemanlar dikeyde doldurulur
        metricsGrid.spacing = 12 // Grid elemanları arası boşluk ayarlanır
        metricsGrid.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır

        stack.addArrangedSubview(metricsGrid) // Grid stack'e eklenir

        view.addSubview(stack) // Stack ana görünüme eklenir

        NSLayoutConstraint.activate([ // AutoLayout kısıtlamaları aktif edilir
            map.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), // Harita üstü safe area'ya hizalanır
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor), // Harita sol kenar ana görünüme hizalanır
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor), // Harita sağ kenar ana görünüme hizalanır
            // Haritayı biraz küçült → istatistikler bloğu daha yukarı
            map.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.58), // harita çok az yukarı alındı, metriklerle hizalandı

            stack.topAnchor.constraint(equalTo: map.bottomAnchor), // Stack üstü haritanın altına hizalanır
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor), // Stack sol kenarı ana görünüme hizalanır
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor), // Stack sağ kenarı ana görünüme hizalanır
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor) // Stack altı safe area'ya yapışsın (altta boşluk kalmasın)
        ])
    }

    // MARK: - Card Helpers

    func makeCardContainer() -> UIView { // Kart konteyneri oluşturma fonksiyonu
        let card = UIView() // UIView nesnesi oluşturulur
        card.backgroundColor = .tertiarySystemBackground // Arka plan rengi ayarlanır
        card.layer.cornerRadius = 14 // Köşe yuvarlama uygulanır
        card.layer.borderWidth = 0.5 // Kenarlık kalınlığı ayarlanır
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor // Kenarlık rengi ayarlanır
        card.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır
        return card // Kart döndürülür
    }

    func makeIconBadge(systemName: String, tint: UIColor, size: CGFloat = 16) -> UIView { // İkon rozeti oluşturma fonksiyonu
        let wrap = UIView() // Konteyner UIView oluşturulur
        wrap.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır
        wrap.backgroundColor = .secondarySystemBackground // Arka plan rengi ayarlanır
        wrap.layer.cornerRadius = 14 // Köşe yuvarlama uygulanır

        let iv = UIImageView(image: UIImage(systemName: systemName)) // Sistem ikonlu UIImageView oluşturulur
        iv.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır
        iv.contentMode = .scaleAspectFit // İçerik modunu ayarlar
        iv.tintColor = tint // İkon rengi ayarlanır

        wrap.addSubview(iv) // İkon konteynere eklenir
        NSLayoutConstraint.activate([ // Kısıtlamalar aktif edilir
            iv.centerXAnchor.constraint(equalTo: wrap.centerXAnchor), // İkon yatayda ortalanır
            iv.centerYAnchor.constraint(equalTo: wrap.centerYAnchor), // İkon dikeyde ortalanır
            iv.widthAnchor.constraint(equalToConstant: size), // İkon genişliği sabitlenir
            iv.heightAnchor.constraint(equalToConstant: size), // İkon yüksekliği sabitlenir
            wrap.widthAnchor.constraint(equalToConstant: 28), // Konteyner genişliği sabitlenir
            wrap.heightAnchor.constraint(equalToConstant: 28) // Konteyner yüksekliği sabitlenir
        ])
        return wrap // Rozet döndürülür
    }

    func makeMetricCard(title: String, value: String, icon: String) -> UIStackView { // Metrik kartı oluşturma fonksiyonu
        // Outer card
        let card = makeCardContainer() // Kart konteyneri oluşturulur

        // Icon tint mapping
        let tint: UIColor // İkon rengi değişkeni
        if title == "Kalori" { // Kalori kartı ise
            tint = UIColor(hex: "#FF6B3D") // Turuncu tonunda renk atanır
        } else if title == "Mesafe" { // Mesafe kartı ise
            tint = UIColor(hex: "#006BFF") // Mavi tonunda renk atanır
        } else if title == "Tempo" { // Tempo kartı ise
            tint = .systemGreen // Sistem yeşili atanır
        } else if title == "Süre" { // Süre kartı ise
            tint = .systemPurple // Sistem moru atanır
        } else {
            tint = UIColor(hex: "#006BFF") // Varsayılan mavi renk atanır
        }

        let iconSize: CGFloat = (title == "Mesafe") ? 18 : 16 // Mesafe kartı için ikon boyutu farklıdır
        let iconWrap = makeIconBadge(systemName: icon, tint: tint, size: iconSize) // İkon rozeti oluşturulur

        // Labels
        let titleLabel = UILabel() // Başlık label'ı oluşturulur
        titleLabel.text = title // Başlık metni atanır
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold) // Yazı tipi ve kalınlık ayarlanır
        titleLabel.textColor = .secondaryLabel // Yazı rengi atanır

        let valueLabel = UILabel() // Değer label'ı oluşturulur
        valueLabel.text = value // Değer metni atanır
        valueLabel.font = .systemFont(ofSize: 20, weight: .semibold) // Yazı tipi ve kalınlık ayarlanır
        valueLabel.textColor = .label // Yazı rengi atanır

        let labels = UIStackView(arrangedSubviews: [titleLabel, valueLabel]) // Başlık ve değer stack'te birleştirilir
        labels.axis = .vertical // Stack dikey hizalanır
        labels.spacing = 4 // Elemanlar arası boşluk ayarlanır

        // Inner horizontal content
        let inner = UIStackView(arrangedSubviews: [iconWrap, labels]) // İkon ve label'lar yatay stack'te birleştirilir
        inner.axis = .horizontal // Stack yatay hizalanır
        inner.alignment = .center // Elemanlar ortalanır
        inner.spacing = 12 // Elemanlar arası boşluk ayarlanır
        inner.isLayoutMarginsRelativeArrangement = true // Marginlere göre düzenleme aktif edilir
        inner.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12) // İçerik kenar boşlukları ayarlanır
        inner.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır

        card.addSubview(inner) // İçerik karta eklenir
        NSLayoutConstraint.activate([ // Kısıtlamalar aktif edilir
            inner.topAnchor.constraint(equalTo: card.topAnchor), // İçerik üstü karta hizalanır
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor), // İçerik sol kenarı karta hizalanır
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor), // İçerik sağ kenarı karta hizalanır
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor), // İçerik altı karta hizalanır
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 70) // Kart minimum yüksekliği ayarlanır
        ])

        let wrapper = UIStackView(arrangedSubviews: [card]) // Kart bir stack içine alınır
        wrapper.axis = .vertical // Stack dikey hizalanır
        wrapper.alignment = .fill // Elemanlar yatayda doldurulur
        return wrapper // Stack döndürülür
    }
}
