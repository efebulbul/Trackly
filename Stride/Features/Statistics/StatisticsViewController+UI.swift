//
//  StatisticsViewController+UI.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır

extension StatisticsViewController { // StatisticsViewController için bir extension başlatır

    // MARK: - UI Setup
    func setupUI() { // UI bileşenlerini kuran fonksiyon
        scrollView.translatesAutoresizingMaskIntoConstraints = false // scrollView Auto Layout kullanacak
        contentView.translatesAutoresizingMaskIntoConstraints = false // contentView Auto Layout kullanacak

        view.addSubview(scrollView) // scrollView'u ana görünüme ekler
        scrollView.addSubview(contentView) // contentView'u scrollView içine ekler

        NSLayoutConstraint.activate([ // Auto Layout kısıtlamalarını etkinleştirir
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), // scrollView üst kenarını safe area üstüne hizalar
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor), // scrollView sol kenarını view sol kenarına hizalar
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor), // scrollView sağ kenarını view sağ kenarına hizalar
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor), // scrollView alt kenarını view alt kenarına hizalar

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor), // contentView üst kenarını scrollView içeriğinin üstüne hizalar
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor), // contentView sol kenarını scrollView içeriğinin soluna hizalar
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor), // contentView sağ kenarını scrollView içeriğinin sağına hizalar
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor), // contentView alt kenarını scrollView içeriğinin altına hizalar
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor) // contentView genişliğini scrollView genişliğine eşitler
        ])

        contentStack.axis = .vertical // contentStack dikey eksende düzenlenecek
        contentStack.alignment = .fill // içerik dolacak şekilde hizalanacak
        contentStack.distribution = .fill // içerik dolacak şekilde dağıtılacak
        contentStack.spacing = 12 // içerikler arasında 12 nokta boşluk olacak
        contentStack.translatesAutoresizingMaskIntoConstraints = false // Auto Layout kullanacak

        contentView.addSubview(contentStack) // contentStack'i contentView içine ekler

        NSLayoutConstraint.activate([ // contentStack için Auto Layout kısıtlamaları
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8), // contentStack üst kenarı contentView üstünden 8 nokta aşağıda
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16), // contentStack sol kenarı contentView solundan 16 nokta içeride
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16), // contentStack sağ kenarı contentView sağından 16 nokta içeride
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16) // contentStack alt kenarı contentView altından 16 nokta içeride
        ])

        // Header (hafta/ay/yıl navigasyonu)
        header.axis = .horizontal // header yatay eksende düzenlenecek
        header.alignment = .center // içerikler ortalanacak
        header.distribution = .equalCentering // içerikler eşit aralıkta ortalanacak
        header.spacing = 12 // içerikler arasında 12 nokta boşluk olacak

        prevButton.setImage(UIImage(systemName: "chevron.left"), for: .normal) // prevButton'a sol ok ikonu atanır
        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal) // nextButton'a sağ ok ikonu atanır

        prevButton.addTarget(self, action: #selector(prevPeriod), for: .touchUpInside) // prevButton'a dokunulduğunda prevPeriod fonksiyonunu çağırır
        nextButton.addTarget(self, action: #selector(nextPeriod), for: .touchUpInside) // nextButton'a dokunulduğunda nextPeriod fonksiyonunu çağırır

        periodLabel.font = .systemFont(ofSize: 16, weight: .semibold) // periodLabel yazı tipi ve ağırlığı ayarlanır
        periodLabel.textColor = .label // periodLabel yazı rengi ayarlanır
        periodLabel.textAlignment = .center // periodLabel ortalanır
        periodLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal) // yatayda sıkışma önceliği yüksek yapılır

        header.addArrangedSubview(prevButton) // header'a prevButton eklenir
        header.addArrangedSubview(periodLabel) // header'a periodLabel eklenir
        header.addArrangedSubview(nextButton) // header'a nextButton eklenir

        prevButton.setContentHuggingPriority(.required, for: .horizontal) // prevButton yatayda sıkışma önceliği zorunlu olur
        nextButton.setContentHuggingPriority(.required, for: .horizontal) // nextButton yatayda sıkışma önceliği zorunlu olur
        prevButton.widthAnchor.constraint(equalTo: nextButton.widthAnchor).isActive = true // prevButton ve nextButton genişlikleri eşitlenir

        // Period segmented control
        periodControl.translatesAutoresizingMaskIntoConstraints = false // periodControl Auto Layout kullanacak
        periodControl.addTarget(self, action: #selector(periodChanged(_:)), for: .valueChanged) // periodControl değeri değiştiğinde periodChanged fonksiyonunu çağırır

        totalLabel.font = .systemFont(ofSize: 14, weight: .semibold) // totalLabel yazı tipi ve ağırlığı ayarlanır
        totalLabel.textColor = .label // totalLabel yazı rengi ayarlanır
        totalLabel.textAlignment = .left // totalLabel sola hizalanır

        // Kart stilini ortaktan ver
        func styleCard(_ v: UIView) { // kart görünümü için ortak stil fonksiyonu
            v.backgroundColor = .tertiarySystemBackground // arka plan rengi ayarlanır
            v.layer.cornerRadius = 14 // köşe yuvarlama uygulanır
            v.layer.borderWidth = 0.5 // kenarlık kalınlığı ayarlanır
            v.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor // kenarlık rengi ayarlanır
            v.translatesAutoresizingMaskIntoConstraints = false // Auto Layout kullanacak
        }

        styleCard(kcalCard) // kcalCard stil uygulanır
        styleCard(kmCard) // kmCard stil uygulanır
        styleCard(durationCard) // durationCard stil uygulanır
        styleCard(paceCard) // paceCard stil uygulanır

        // Kart içerikleri
        setupDurationCard() // durationCard içeriği ayarlanır
        setupKmCard() // kmCard içeriği ayarlanır
        setupPaceCard() // paceCard içeriği ayarlanır
        setupKcalCard() // kcalCard içeriği ayarlanır

        // Chart container’lar
        [kcalChartContainer, kmChartContainer, durationChartContainer, paceChartContainer].forEach { container in // her chart container için
            container.translatesAutoresizingMaskIntoConstraints = false // Auto Layout kullanacak
            container.backgroundColor = .secondarySystemBackground // arka plan rengi ayarlanır
            container.layer.cornerRadius = 16 // köşe yuvarlama uygulanır
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true // yüksekliği en az 160 olarak ayarlanır
        }

        summaryLabel.font = .systemFont(ofSize: 13, weight: .medium) // summaryLabel yazı tipi ve ağırlığı ayarlanır
        summaryLabel.textColor = .secondaryLabel // summaryLabel yazı rengi ayarlanır
        summaryLabel.numberOfLines = 2 // summaryLabel maksimum 2 satır olarak ayarlanır

        // Sıralama: Süre, Mesafe, Tempo, Kalori, Adım
        contentStack.addArrangedSubview(header) // contentStack'e header eklenir
        contentStack.addArrangedSubview(periodControl) // contentStack'e periodControl eklenir
        contentStack.setCustomSpacing(8, after: periodControl) // periodControl sonrası 8 nokta boşluk ayarlanır

        contentStack.addArrangedSubview(totalLabel) // contentStack'e totalLabel eklenir
        contentStack.setCustomSpacing(12, after: totalLabel) // totalLabel sonrası 12 nokta boşluk ayarlanır

        contentStack.addArrangedSubview(durationCard) // contentStack'e durationCard eklenir
        contentStack.addArrangedSubview(durationChartContainer) // contentStack'e durationChartContainer eklenir

        contentStack.addArrangedSubview(kmCard) // contentStack'e kmCard eklenir
        contentStack.addArrangedSubview(kmChartContainer) // contentStack'e kmChartContainer eklenir

        contentStack.addArrangedSubview(paceCard) // contentStack'e paceCard eklenir
        contentStack.addArrangedSubview(paceChartContainer) // contentStack'e paceChartContainer eklenir

        contentStack.addArrangedSubview(kcalCard) // contentStack'e kcalCard eklenir
        contentStack.addArrangedSubview(kcalChartContainer) // contentStack'e kcalChartContainer eklenir

        contentStack.addArrangedSubview(summaryLabel) // contentStack'e summaryLabel eklenir
    }

    // Ortak kart kurulum helper'ı (ikon + başlık + sağda büyük değer)
    func configureMetricCard( // metric kartları için ortak yapılandırma fonksiyonu
        container: UIView, // kart konteyneri
        iconSystemName: String, // ikonun sistem adı
        iconTint: UIColor, // ikon rengi
        titleText: String, // başlık metni
        valueLabel: UILabel, // değer etiketi
        iconWidth: CGFloat = 16, // ikon genişliği varsayılan 16
        iconHeight: CGFloat = 16 // ikon yüksekliği varsayılan 16
    ) {
        let iconWrap = UIView() // ikon için sarmalayıcı görünüm oluşturulur
        iconWrap.translatesAutoresizingMaskIntoConstraints = false // Auto Layout kullanacak
        iconWrap.backgroundColor = .secondarySystemBackground // arka plan rengi ayarlanır
        iconWrap.layer.cornerRadius = 14 // köşe yuvarlama uygulanır
        // Kalori ikonunda: koyu dolgu + turuncu çerçeve (Run ekranındaki gibi)
        iconWrap.layer.borderWidth = 0
        iconWrap.layer.borderColor = UIColor.clear.cgColor

        if titleText == "Kalori" {
            iconWrap.backgroundColor = UIColor.black.withAlphaComponent(0.85)
            iconWrap.layer.borderWidth = 1
            iconWrap.layer.borderColor = UIColor(hex: "#FF6B3D").cgColor
        }

        let icon = UIImageView(image: UIImage(systemName: iconSystemName)) // ikon UIImageView olarak oluşturulur
        icon.tintColor = iconTint // ikonun rengi ayarlanır
        icon.contentMode = .scaleAspectFit // ikon içeriği ölçeklenir
        icon.translatesAutoresizingMaskIntoConstraints = false // Auto Layout kullanacak
        iconWrap.addSubview(icon) // ikon sarmalayıcıya eklenir

        NSLayoutConstraint.activate([ // ikon ve sarmalayıcı için kısıtlamalar
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor), // ikon yatayda ortalanır
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor), // ikon dikeyde ortalanır
            icon.widthAnchor.constraint(equalToConstant: iconWidth), // ikon genişliği sabitlenir
            icon.heightAnchor.constraint(equalToConstant: iconHeight), // ikon yüksekliği sabitlenir
            iconWrap.widthAnchor.constraint(equalToConstant: 28), // sarmalayıcı genişliği sabitlenir
            iconWrap.heightAnchor.constraint(equalToConstant: 28) // sarmalayıcı yüksekliği sabitlenir
        ])

        let title = UILabel() // başlık etiketi oluşturulur
        title.text = titleText // başlık metni atanır
        title.font = .systemFont(ofSize: 12, weight: .semibold) // başlık yazı tipi ayarlanır
        title.textColor = .secondaryLabel // başlık rengi ayarlanır

        let headerStack = UIStackView(arrangedSubviews: [iconWrap, title]) // ikon ve başlık yatay stack içinde gruplanır
        headerStack.axis = .horizontal // yatay eksende düzenlenir
        headerStack.alignment = .center // ortalanır
        headerStack.spacing = 8 // aralarında 8 nokta boşluk olur

        valueLabel.font = .systemFont(ofSize: 24, weight: .bold) // değer etiketi yazı tipi ayarlanır
        valueLabel.textColor = .label // değer etiketi rengi ayarlanır
        valueLabel.textAlignment = .right // sağa hizalanır

        let hStack = UIStackView(arrangedSubviews: [headerStack, valueLabel]) // başlık ve değer yatay stack içinde gruplanır
        hStack.axis = .horizontal // yatay eksende düzenlenir
        hStack.alignment = .center // ortalanır
        hStack.distribution = .equalSpacing // eşit boşluklarla dağıtılır
        hStack.spacing = 8 // aralarında 8 nokta boşluk olur
        hStack.isLayoutMarginsRelativeArrangement = true // layout margins kullanılır
        hStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12) // iç boşluklar ayarlanır
        hStack.translatesAutoresizingMaskIntoConstraints = false // Auto Layout kullanacak

        headerStack.setContentHuggingPriority(.required, for: .horizontal) // headerStack yatayda sıkışma önceliği zorunlu
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal) // valueLabel yatayda sıkışma önceliği düşük
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal) // valueLabel yatayda sıkıştırmaya direnç zorunlu

        container.addSubview(hStack) // hStack konteynere eklenir
        NSLayoutConstraint.activate([ // hStack için kısıtlamalar
            hStack.topAnchor.constraint(equalTo: container.topAnchor), // üst kenar hizalanır
            hStack.leadingAnchor.constraint(equalTo: container.leadingAnchor), // sol kenar hizalanır
            hStack.trailingAnchor.constraint(equalTo: container.trailingAnchor), // sağ kenar hizalanır
            hStack.bottomAnchor.constraint(equalTo: container.bottomAnchor), // alt kenar hizalanır
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 72) // konteyner yüksekliği en az 72 olur
        ])
    }

    // MARK: - Card Setup
    func setupKcalCard() { // kcalCard yapılandırma fonksiyonu
        configureMetricCard(
            container: kcalCard,
            iconSystemName: "flame",
            iconTint: UIColor(hex: "#FF6B3D"),
            titleText: "Kalori",
            valueLabel: kcalValueLabel,
            iconWidth: 16,
            iconHeight: 16
        )
    }

    func setupKmCard() { // kmCard yapılandırma fonksiyonu
        configureMetricCard( // configureMetricCard fonksiyonunu çağırır
            container: kmCard, // kmCard konteyneri
            iconSystemName: "map", // ikon adı
            iconTint: UIColor .appBlue,
            titleText: "Mesafe", // başlık metni
            valueLabel: kmValueLabel, // değer etiketi
            iconWidth: 18, // ikon genişliği
            iconHeight: 18 // ikon yüksekliği
        )
    }

    func setupDurationCard() { // durationCard yapılandırma fonksiyonu
        configureMetricCard( // configureMetricCard fonksiyonunu çağırır
            container: durationCard, // durationCard konteyneri
            iconSystemName: "timer", // ikon adı
            iconTint: .systemPurple, // ikon rengi
            titleText: "Süre", // başlık metni
            valueLabel: durationValueLabel, // değer etiketi
            iconWidth: 16, // ikon genişliği
            iconHeight: 16 // ikon yüksekliği
        )
    }

    func setupPaceCard() { // paceCard yapılandırma fonksiyonu
        configureMetricCard( // configureMetricCard fonksiyonunu çağırır
            container: paceCard, // paceCard konteyneri
            iconSystemName: "speedometer", // ikon adı
            iconTint: .systemGreen, // ikon rengi
            titleText: "Tempo", // başlık metni
            valueLabel: paceValueLabel, // değer etiketi
            iconWidth: 18, // ikon genişliği
            iconHeight: 18 // ikon yüksekliği
        )
    }


    // MARK: - Brand Title
    func applyBrandTitle() { // markanın başlığını uygulayan fonksiyon
        let label = UILabel() // yeni bir UILabel oluşturur
        let title = NSMutableAttributedString( // Attributed string oluşturur
            string: "Stride", // ilk metin parçası
            attributes: [ // ilk metin için özellikler
                .foregroundColor: UIColor.label, // metin rengi
                .font: UIFont.boldSystemFont(ofSize: 30) // kalın font ve boyutu
            ]
        )
       
        title.append(NSAttributedString( // ikinci metin parçası eklenir
            string: "X", // metin
            attributes: [
                .foregroundColor: UIColor(hex: "#006BFF"), // Mavi renk
                .font: UIFont.boldSystemFont(ofSize: 30)
            ]
        ))
        label.attributedText = title // label'ın attributedText özelliğine atanır
        navigationItem.titleView = label // navigation bar başlığı olarak atanır
    }
}

// MARK: - Hex Color Helper
extension UIColor {
    /// Creates a UIColor from hex strings like "#RRGGBB" or "RRGGBB" (optionally with "#AARRGGBB").
    convenience init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexString = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed

        var value: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&value)

        let a, r, g, b: CGFloat
        switch hexString.count {
        case 8: // AARRGGBB
            a = CGFloat((value & 0xFF000000) >> 24) / 255.0
            r = CGFloat((value & 0x00FF0000) >> 16) / 255.0
            g = CGFloat((value & 0x0000FF00) >> 8) / 255.0
            b = CGFloat(value & 0x000000FF) / 255.0
        case 6: // RRGGBB
            a = 1.0
            r = CGFloat((value & 0xFF0000) >> 16) / 255.0
            g = CGFloat((value & 0x00FF00) >> 8) / 255.0
            b = CGFloat(value & 0x0000FF) / 255.0
        default:
            a = 1.0
            r = 0
            g = 0
            b = 0
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
