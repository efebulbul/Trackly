//
//  RunViewController+UI.swift
//  Stride
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
        bottomPanel.backgroundColor = .clear // Harita görünsün (arka plan yok)
        bottomPanel.layer.cornerRadius = 0
        bottomPanel.layer.shadowOpacity = 0
        view.addSubview(bottomPanel) // Alt paneli ana görünüme ekler
        bottomPanel.isUserInteractionEnabled = true

        // İç dikey stack
        contentStack.axis = .vertical // Yönünü dikey yapar
        contentStack.alignment = .fill // Hizalamayı doldurur
        contentStack.distribution = .fill // Dağılımı doldurur
        contentStack.spacing = 12
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 14, right: 16)
        contentStack.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır
        bottomPanel.addSubview(contentStack) // İçeriği alt panele ekler

        // Strava-like "glass" background: blur + subtle tint + stroke
        let glass = UIView()
        glass.translatesAutoresizingMaskIntoConstraints = false
        // Same surface color as the tracking button background
        glass.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.92)
        glass.layer.cornerRadius = 18
        glass.layer.borderWidth = 1
        glass.layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor
        glass.layer.shadowColor = UIColor.black.cgColor
        glass.layer.shadowOpacity = 0.10
        glass.layer.shadowRadius = 16
        glass.layer.shadowOffset = CGSize(width: 0, height: 6)

        bottomPanel.insertSubview(glass, belowSubview: contentStack)

        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.alpha = 0.90
        blurView.layer.cornerRadius = 18
        blurView.clipsToBounds = true
        glass.addSubview(blurView)

        NSLayoutConstraint.activate([
            // Glass container follows the content (with small inset so it feels like a pill)
            glass.topAnchor.constraint(equalTo: contentStack.topAnchor),
            glass.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 8),
            glass.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -8),
            glass.bottomAnchor.constraint(equalTo: contentStack.bottomAnchor),

            // Blur fills the glass
            blurView.topAnchor.constraint(equalTo: glass.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: glass.bottomAnchor)
        ])

        // Strava-like expand button (opens full-screen metrics)
        let expandBtn = UIButton(type: .system)
        expandBtn.translatesAutoresizingMaskIntoConstraints = false
        expandBtn.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right.circle.fill"), for: .normal)
        expandBtn.tintColor = .white
        expandBtn.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        expandBtn.layer.cornerRadius = 20
        expandBtn.clipsToBounds = true
        expandBtn.addTarget(self, action: #selector(showFullMetrics), for: .touchUpInside)

        bottomPanel.addSubview(expandBtn)
        bottomPanel.bringSubviewToFront(expandBtn)

        NSLayoutConstraint.activate([
            expandBtn.topAnchor.constraint(equalTo: glass.topAnchor, constant: -20),
            expandBtn.trailingAnchor.constraint(equalTo: glass.trailingAnchor, constant: -10),
            expandBtn.widthAnchor.constraint(equalToConstant: 40),
            expandBtn.heightAnchor.constraint(equalToConstant: 40)
        ])

        // Strava-like: sabit 3'lü metrik satırı (Sol=Zaman, Orta=Tempo, Sağ=Mesafe)
        let metricsRow = UIStackView()
        metricsRow.axis = .horizontal
        metricsRow.alignment = .fill
        metricsRow.distribution = .fillEqually
        metricsRow.spacing = 12
        metricsRow.translatesAutoresizingMaskIntoConstraints = false

        let timeCard = makeMetricChip(title: "Zaman", valueLabel: timeValue, systemName: "timer")
        let paceCard = makeMetricChip(title: "Tempo", valueLabel: paceValue, systemName: "speedometer")
        let distCard = makeMetricChip(title: "Mesafe", valueLabel: distValue, systemName: "map")

        metricsRow.addArrangedSubview(timeCard)
        metricsRow.addArrangedSubview(paceCard)
        metricsRow.addArrangedSubview(distCard)

        contentStack.addArrangedSubview(metricsRow)
        contentStack.addArrangedSubview(startButton)
    }

    func layoutConstraints() { // Kısıtlamaları ayarlar
        let safe = view.safeAreaLayoutGuide // Güvenli alan kılavuzunu alır

        NSLayoutConstraint.activate([ // Kısıtlamaları etkinleştirir
            // Map
            mapView.topAnchor.constraint(equalTo: view.topAnchor), // Harita üst kenarını görünümün üstüne hizalar
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor), // Harita sol kenarını görünümün soluna hizalar
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor), // Harita sağ kenarını görünümün sağına hizalar

            // Panel (fixed bottom bar)
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Alt panel tab bar'ın ÜSTÜNDE kalsın (tab bar görünür olsun)
            bottomPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomPanel.heightAnchor.constraint(equalToConstant: 180),

            // Harita tab bar'ın arkasına girmesin
            mapView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            // Panel iç stack
            contentStack.centerYAnchor.constraint(equalTo: bottomPanel.centerYAnchor), // Dikeyde ortala
            contentStack.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor),
        ])
    }

    func addTrackingButton() { // Konum takip butonunu ekler
        // Tracking button (merkezleme butonu)
        let btn = UIButton(type: .system) // Sistem tipi buton oluşturur
        btn.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır
        btn.layer.cornerRadius = 8 // Köşe yarıçapını ayarlar
        // Tracking button background (matches bottom glass surface)
        btn.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.92)

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
        container.backgroundColor = .clear // Harita görünsün
        container.layer.cornerRadius = 0
        container.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır

        let titleLabel = UILabel() // Başlık etiketi oluşturur
        titleLabel.text = title // Başlık metnini ayarlar
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold) // Yazı tipini ayarlar
        titleLabel.textColor = .secondaryLabel // Yazı rengini ayarlar
        titleLabel.textAlignment = .center

        valueLabel.font = .systemFont(ofSize: 18, weight: .bold) // Daha iyi sığsın
        valueLabel.textColor = .label // Değer etiketinin yazı rengini ayarlar
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        valueLabel.numberOfLines = 1
        valueLabel.textAlignment = .center

        let labels = UIStackView(arrangedSubviews: [titleLabel, valueLabel]) // Başlık ve değer etiketlerini yığın içine ekler
        labels.axis = .vertical // Dikey yön
        labels.alignment = .center // Her 1/3 içinde ortala
        labels.spacing = 2 // Elemanlar arası boşluk

        let h = UIStackView(arrangedSubviews: [labels]) // Logo yok: daha fazla alan
        h.axis = .horizontal // Yatay yön
        h.alignment = .center // Ortalanmış hizalama
        h.spacing = 0
        h.isLayoutMarginsRelativeArrangement = true // Kenar boşluklarına göre düzenler
        h.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        h.translatesAutoresizingMaskIntoConstraints = false // Otomatik kısıtlamaları devre dışı bırakır

        container.addSubview(h) // Yatay yığını konteynere ekler
        NSLayoutConstraint.activate([ // Kısıtlamaları etkinleştirir
            h.topAnchor.constraint(equalTo: container.topAnchor), // Üst kenar hizalaması
            h.leadingAnchor.constraint(equalTo: container.leadingAnchor), // Sol kenar hizalaması
            h.trailingAnchor.constraint(equalTo: container.trailingAnchor), // Sağ kenar hizalaması
            h.bottomAnchor.constraint(equalTo: container.bottomAnchor), // Alt kenar hizalaması
        ])
        return container // Konteyner görünümünü döner
    }
}
