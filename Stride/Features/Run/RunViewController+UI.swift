//
//  RunViewController+UI.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır
import MapKit // MapKit framework'ünü içe aktarır

extension RunViewController { // RunViewController için genişletme başlatır

    // MARK: - UI Setup

    func setupMap() { // Harita görünümünü ayarlar
        mapView.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır
        mapView.showsCompass = false // Harita üzerinde pusula gösterimini kapatır
        mapView.showsScale = false // Harita üzerinde ölçek gösterimini kapatır
        mapView.pointOfInterestFilter = .includingAll // Harita üzerindeki ilgi noktalarını dahil eder
        mapView.preferredConfiguration = MKStandardMapConfiguration( // Harita konfigürasyonunu ayarlar
            elevationStyle: .realistic, // Yükseklik stilini gerçekçi yapar
            emphasisStyle: .muted // Vurgu stilini sönük yapar
        )
        view.addSubview(mapView) // Harita görünümünü ana görünüme ekler
    }

    func setupBottomPanel() { // Alt paneli ayarlar
        // Panel
        bottomPanel.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır
        bottomPanel.backgroundColor = .secondarySystemBackground // Arka plan rengini ayarlar
        bottomPanel.layer.cornerRadius = 0 // Köşe yuvarlama değerini sıfırlar
        view.addSubview(bottomPanel) // Alt paneli ana görünüme ekler

        // İç dikey stack
        contentStack.axis = .vertical // Yönünü dikey yapar
        contentStack.alignment = .fill // Hizalamayı doldurur
        contentStack.distribution = .fill // Dağılımı doldurur
        contentStack.spacing = 12 // Elemanlar arası boşluğu ayarlar
        contentStack.isLayoutMarginsRelativeArrangement = true // Kenar boşluklarına göre düzenler
        contentStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16) // Kenar boşluklarını ayarlar
        contentStack.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır
        bottomPanel.addSubview(contentStack) // İçeriği alt panele ekler

        // Yatay kaydırılabilir metrik şerit (chip tarzı)
        let metricsScroll = UIScrollView() // Kaydırılabilir görünüm oluşturur
        metricsScroll.showsHorizontalScrollIndicator = false // Yatay kaydırma göstergesini kapatır
        metricsScroll.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır

        let metricsRow = UIStackView() // Yatay yığın görünümü oluşturur
        metricsRow.axis = .horizontal // Yönünü yatay yapar
        metricsRow.alignment = .fill // Hizalamayı doldurur
        metricsRow.distribution = .fill // Dağılımı doldurur
        metricsRow.spacing = 12 // Elemanlar arası boşluğu ayarlar
        metricsRow.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır

        metricsScroll.addSubview(metricsRow) // Metrik satırını kaydırılabilir görünüme ekler
        NSLayoutConstraint.activate([ // Kısıtlamaları etkinleştirir
            metricsRow.topAnchor.constraint(equalTo: metricsScroll.contentLayoutGuide.topAnchor), // Üst kenar hizalaması
            metricsRow.leadingAnchor.constraint(equalTo: metricsScroll.contentLayoutGuide.leadingAnchor), // Sol kenar hizalaması
            metricsRow.trailingAnchor.constraint(equalTo: metricsScroll.contentLayoutGuide.trailingAnchor), // Sağ kenar hizalaması
            metricsRow.bottomAnchor.constraint(equalTo: metricsScroll.contentLayoutGuide.bottomAnchor), // Alt kenar hizalaması
            metricsRow.heightAnchor.constraint(equalTo: metricsScroll.frameLayoutGuide.heightAnchor) // Yükseklik eşitleme
        ])

        // 4 adet chip (Adım kaldırıldı)
        let timeChip  = makeMetricChip(title: "Toplam Süre", valueLabel: timeValue, systemName: "timer")
        let distChip  = makeMetricChip(title: "Mesafe",      valueLabel: distValue, systemName: "map")
        let paceChip  = makeMetricChip(title: "Tempo",       valueLabel: paceValue, systemName: "speedometer")
        let kcalChip  = makeMetricChip(title: "Kalori",      valueLabel: kcalValue, systemName: "flame")

        metricsRow.addArrangedSubview(timeChip)
        metricsRow.addArrangedSubview(distChip)
        metricsRow.addArrangedSubview(paceChip)
        metricsRow.addArrangedSubview(kcalChip)

        // Aynı genişlik
        let chips = [timeChip, distChip, paceChip, kcalChip]

        if let baseChip = chips.first { // İlk chip referans olarak alınır
            chips.forEach { chip in // Her chip için
                chip.widthAnchor.constraint(equalTo: baseChip.widthAnchor).isActive = true // Genişlik eşitliği kısıtlaması ekler
            }
        }

        // Ana dikey stack
        contentStack.addArrangedSubview(metricsScroll) // Metrik kaydırılabilir görünümü ekler
        contentStack.addArrangedSubview(startButton) // Başlat butonunu ekler
    }

    func layoutConstraints() { // Kısıtlamaları ayarlar
        let safe = view.safeAreaLayoutGuide // Güvenli alan kılavuzunu alır

        NSLayoutConstraint.activate([ // Kısıtlamaları etkinleştirir
            // Map
            mapView.topAnchor.constraint(equalTo: view.topAnchor), // Harita üst kenarını görünümün üstüne hizalar
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor), // Harita sol kenarını görünümün soluna hizalar
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor), // Harita sağ kenarını görünümün sağına hizalar

            // Panel
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor), // Alt panel sol kenarını hizalar
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor), // Alt panel sağ kenarını hizalar
            bottomPanel.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12), // Alt panel alt kenarını güvenli alanın 12pt üstüne hizalar
            bottomPanel.topAnchor.constraint(greaterThanOrEqualTo: safe.centerYAnchor), // Alt panel üst kenarını güvenli alanın ortasından aşağıda tutar

            mapView.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor), // Harita alt kenarını alt panel üst kenarına hizalar

            // Panel iç stack
            contentStack.topAnchor.constraint(equalTo: bottomPanel.topAnchor), // İçerik üst kenarını alt panel üst kenarına hizalar
            contentStack.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor), // İçerik sol kenarını alt panel sol kenarına hizalar
            contentStack.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor), // İçerik sağ kenarını alt panel sağ kenarına hizalar
            contentStack.bottomAnchor.constraint(equalTo: bottomPanel.bottomAnchor), // İçerik alt kenarını alt panel alt kenarına hizalar
        ])
    }

    func addTrackingButton() { // Konum takip butonunu ekler
        // Tracking button (merkezleme butonu)
        let btn = UIButton(type: .system) // Sistem tipi buton oluşturur
        btn.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır
        btn.layer.cornerRadius = 8 // Köşe yarıçapını ayarlar
        btn.backgroundColor = .secondarySystemBackground // Arka plan rengini ayarlar

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium) // Sembol konfigürasyonu oluşturur
        let image = UIImage(systemName: "location.fill", withConfiguration: config) // Konum simgesi oluşturur
        btn.setImage(image, for: .normal) // Butona simgeyi normal durumda atar
        btn.tintColor = UIColor(named: "AppBlue") ?? UIColor(red: 0/255, green: 107/255, blue: 255/255, alpha: 1.0) // Simge rengi (fallback dahil)

        btn.addTarget(self, action: #selector(centerOnUserTapped), for: .touchUpInside) // Butona tıklama aksiyonu ekler

        view.addSubview(btn) // Butonu ana görünüme ekler

        // Compass button (pusula)
        let compass = MKCompassButton(mapView: mapView) // Harita pusula butonunu oluşturur
        compass.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır
        compass.compassVisibility = .visible // Pusula görünürlüğünü aktif eder

        view.addSubview(compass) // Pusula butonunu ana görünüme ekler

        NSLayoutConstraint.activate([ // Kısıtlamaları etkinleştirir
            // Compass
            compass.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12), // Pusula üst kenarını güvenli alan üst kenarına 12pt uzaklıkta hizalar
            compass.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12), // Pusula sağ kenarını görünüm sağ kenarına 12pt uzaklıkta hizalar
            compass.widthAnchor.constraint(equalToConstant: 40), // Pusula genişliğini 40pt yapar
            compass.heightAnchor.constraint(equalToConstant: 40), // Pusula yüksekliğini 40pt yapar

            // Tracking
            btn.topAnchor.constraint(equalTo: compass.bottomAnchor, constant: 8), // Buton üst kenarını pusula alt kenarına 8pt uzaklıkta hizalar
            btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12), // Buton sağ kenarını görünüm sağ kenarına 12pt uzaklıkta hizalar
            btn.widthAnchor.constraint(equalToConstant: 40), // Buton genişliğini 40pt yapar
            btn.heightAnchor.constraint(equalToConstant: 40) // Buton yüksekliğini 40pt yapar
        ])
    }

    @objc func centerOnUserTapped() { // Kullanıcı konumuna merkezleme fonksiyonu
        guard let coord = mapView.userLocation.location?.coordinate else { return } // Kullanıcı konumunu alır, yoksa çıkış yapar
        let region = MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800) // Bölgeyi kullanıcı konumu etrafında 800m çapında ayarlar
        mapView.setRegion(region, animated: true) // Haritayı bu bölgeye animasyonla ayarlar
    }

    func makeMetricChip(title: String, valueLabel: UILabel, systemName: String) -> UIView { // Metrik chip görünümü oluşturur
        let container = UIView() // Ana konteyner görünümü oluşturur
        container.backgroundColor = .tertiarySystemBackground // Arka plan rengini ayarlar
        container.layer.cornerRadius = 16 // Köşe yarıçapını ayarlar
        container.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır

        // Sol ikon (daire arkaplan)
        let iconWrap = UIView() // İkon için arka plan görünümü oluşturur
        iconWrap.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır
        iconWrap.backgroundColor = .secondarySystemBackground // Arka plan rengini ayarlar
        iconWrap.layer.cornerRadius = 18 // Köşe yarıçapını ayarlar

        let icon = UIImageView(image: UIImage(systemName: systemName)) // Sistem simgesi görseli oluşturur
        icon.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır
        icon.contentMode = .scaleAspectFit // İçeriği orantılı sığdırır

        // History / Statistics ikon renkleri ile uyumlu
        switch title { // Başlığa göre ikon rengini belirler
        case "Toplam Süre":
            icon.tintColor = .systemPurple // Mor renk
        case "Mesafe":
            icon.tintColor = UIColor(hex: "#006BFF") // Mavi renk
        case "Tempo":
            icon.tintColor = .systemGreen // Yeşil renk
        case "Kalori":
            icon.tintColor = UIColor(red: 1.0, green: 0.42, blue: 0.24, alpha: 1.0) // Turuncu renk
        default:
            icon.tintColor = .label // Varsayılan yazı rengi
        }

        iconWrap.addSubview(icon) // İkonu arka plan görünümüne ekler
        NSLayoutConstraint.activate([ // Kısıtlamaları etkinleştirir
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor), // İkon yatay merkezleme
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor), // İkon dikey merkezleme
            icon.widthAnchor.constraint(equalToConstant: 18), // İkon genişliği 18pt
            icon.heightAnchor.constraint(equalToConstant: 18), // İkon yüksekliği 18pt
            iconWrap.widthAnchor.constraint(equalToConstant: 36), // Arka plan genişliği 36pt
            iconWrap.heightAnchor.constraint(equalToConstant: 36) // Arka plan yüksekliği 36pt
        ])

        let titleLabel = UILabel() // Başlık etiketi oluşturur
        titleLabel.text = title // Başlık metnini ayarlar
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold) // Yazı tipini ayarlar
        titleLabel.textColor = .secondaryLabel // Yazı rengini ayarlar

        valueLabel.font = .systemFont(ofSize: 20, weight: .bold) // Değer etiketinin yazı tipini ayarlar
        valueLabel.textColor = .label // Değer etiketinin yazı rengini ayarlar

        let labels = UIStackView(arrangedSubviews: [titleLabel, valueLabel]) // Başlık ve değer etiketlerini yığın içine ekler
        labels.axis = .vertical // Dikey yön
        labels.spacing = 2 // Elemanlar arası boşluk

        let h = UIStackView(arrangedSubviews: [iconWrap, labels]) // İkon ve etiket yığınını yatay yığına ekler
        h.axis = .horizontal // Yatay yön
        h.alignment = .center // Ortalanmış hizalama
        h.spacing = 10 // Elemanlar arası boşluk
        h.isLayoutMarginsRelativeArrangement = true // Kenar boşluklarına göre düzenler
        h.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12) // Kenar boşlukları
        h.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır

        container.addSubview(h) // Yatay yığını konteynere ekler
        NSLayoutConstraint.activate([ // Kısıtlamaları etkinleştirir
            h.topAnchor.constraint(equalTo: container.topAnchor), // Üst kenar hizalaması
            h.leadingAnchor.constraint(equalTo: container.leadingAnchor), // Sol kenar hizalaması
            h.trailingAnchor.constraint(equalTo: container.trailingAnchor), // Sağ kenar hizalaması
            h.bottomAnchor.constraint(equalTo: container.bottomAnchor), // Alt kenar hizalaması
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 60) // Konteyner minimum yüksekliği 60pt
        ])
        return container // Konteyner görünümünü döner
    }
}
