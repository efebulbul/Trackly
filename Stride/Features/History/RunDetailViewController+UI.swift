//
//  RunDetailViewController+UI.swift
//  Stride
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır

extension RunDetailViewController { // RunDetailViewController için extension başlatılır

    func setupLayout() { // Layout kurulum fonksiyonu tanımlanır
        map.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır
        map.delegate = self // Harita delegesi atanır
        view.addSubview(map) // Harita görünümü ana görünüme eklenir

        // Bottom panel container (transparent; map stays visible)
        let bottomPanel = UIView()
        bottomPanel.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.backgroundColor = .clear
        view.addSubview(bottomPanel)

        stack.axis = .vertical // Stack dikey eksende hizalanır
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır

        // 2x2 symmetric metric grid (cards) - initial values match Run screen helpers
        durRow  = makeMetricCard(
            title: "Süre",
            value: durationText(),
            icon: "timer"
        )
        distRow = makeMetricCard(
            title: "Mesafe",
            value: distanceTextForCurrentUnit(),
            icon: "map"
        )
        paceRow = makeMetricCard(
            title: "Tempo",
            value: paceTextForCurrentUnit(),
            icon: "speedometer"
        )
        kcalRow = makeMetricCard(
            title: "Kalori",
            value: kcalText(),
            icon: "flame"
        )

        // Strava-like: top row = Time (left) • Pace (center) • Distance (right)
        let topRow = UIStackView(arrangedSubviews: [durRow, paceRow, distRow])
        topRow.axis = .horizontal
        topRow.distribution = .fillEqually
        topRow.alignment = .fill
        topRow.spacing = 12
        topRow.translatesAutoresizingMaskIntoConstraints = false

        // Calories full-width below
        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(kcalRow)

        bottomPanel.addSubview(stack) // Stack alt panele eklenir

        // Glass background behind metrics (Run screen ile aynı stil)
        let glass = UIView()
        glass.translatesAutoresizingMaskIntoConstraints = false
        // Let the blur do the work; keep the container itself transparent
        glass.backgroundColor = .clear
        glass.layer.cornerRadius = 18
        glass.layer.borderWidth = 1
        glass.layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor
        glass.layer.shadowColor = UIColor.black.cgColor
        glass.layer.shadowOpacity = 0.10
        glass.layer.shadowRadius = 16
        glass.layer.shadowOffset = CGSize(width: 0, height: 6)

        bottomPanel.insertSubview(glass, belowSubview: stack)

        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.alpha = 1.0
        blurView.layer.cornerRadius = 18
        blurView.clipsToBounds = true
        glass.addSubview(blurView)

        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: stack.topAnchor),
            glass.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 8),
            glass.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -8),
            glass.bottomAnchor.constraint(equalTo: stack.bottomAnchor),

            blurView.topAnchor.constraint(equalTo: glass.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: glass.bottomAnchor)
        ])

        // Strava-like expand button (opens full metrics)
        let expandBtn = UIButton(type: .system)
        expandBtn.translatesAutoresizingMaskIntoConstraints = false
        expandBtn.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right.circle.fill"), for: .normal)
        expandBtn.tintColor = .white
        expandBtn.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        expandBtn.layer.cornerRadius = 20
        expandBtn.clipsToBounds = true
        expandBtn.addTarget(self, action: #selector(showFullMetricsDetail), for: .touchUpInside)
        bottomPanel.addSubview(expandBtn)
        bottomPanel.bringSubviewToFront(expandBtn)

        NSLayoutConstraint.activate([
            // Map full screen
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Bottom panel (fixed)
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomPanel.heightAnchor.constraint(equalToConstant: 200),

            // Stack inside panel
            stack.topAnchor.constraint(equalTo: bottomPanel.topAnchor),
            stack.leadingAnchor.constraint(equalTo: bottomPanel.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomPanel.bottomAnchor),

            // Expand button
            expandBtn.topAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: -20),
            expandBtn.trailingAnchor.constraint(equalTo: bottomPanel.trailingAnchor, constant: -14),
            expandBtn.widthAnchor.constraint(equalToConstant: 40),
            expandBtn.heightAnchor.constraint(equalToConstant: 40),
        ])
        // Not: Mesafe ve tempo değerleri, kullanıcının km/mi seçimine göre
        // RunDetailViewController içindeki refreshAllMetricTexts() tarafından güncellenir.
    }

    // MARK: - Actions
    @objc func showFullMetricsDetail() {
        let vc = RunDetailFullMetricsViewController(
            source: self,
            durRow: durRow,
            paceRow: paceRow,
            distRow: distRow,
            kcalRow: kcalRow
        )
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    // MARK: - Card Helpers

    func makeCardContainer() -> UIView { // Kart konteyneri oluşturma fonksiyonu
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear

        // Outer shadow (so it doesn't look like a black block on the map)
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.10
        card.layer.shadowRadius = 14
        card.layer.shadowOffset = CGSize(width: 0, height: 6)

        // Inner "glass" surface (clips blur)
        let surface = UIView()
        surface.translatesAutoresizingMaskIntoConstraints = false
        surface.layer.cornerRadius = 16
        surface.clipsToBounds = true
        surface.layer.borderWidth = 1
        surface.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        card.addSubview(surface)

        // Blur
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.alpha = 1.0
        surface.addSubview(blur)

        // Lighter tint so cards don't feel like dark boxes
        let tint = UIView()
        tint.translatesAutoresizingMaskIntoConstraints = false
        tint.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.18)
        surface.addSubview(tint)

        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: card.topAnchor),
            surface.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            surface.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            blur.topAnchor.constraint(equalTo: surface.topAnchor),
            blur.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: surface.bottomAnchor),

            tint.topAnchor.constraint(equalTo: surface.topAnchor),
            tint.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: surface.bottomAnchor)
        ])

        return card
    }

    func makeIconBadge(systemName: String, tint: UIColor, size: CGFloat = 18) -> UIView { // İkon rozeti oluşturma fonksiyonu
        let wrap = UIView() // Konteyner UIView oluşturulur
        wrap.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır
        wrap.backgroundColor = .secondarySystemBackground // Arka plan rengi ayarlanır
        wrap.layer.cornerRadius = 18 // RunViewController chip ile aynı

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
            wrap.widthAnchor.constraint(equalToConstant: 36), // RunViewController chip ile aynı
            wrap.heightAnchor.constraint(equalToConstant: 36) // RunViewController chip ile aynı
        ])
        return wrap // Rozet döndürülür
    }

    func makeMetricCard(title: String, value: String, icon: String) -> UIStackView { // Metrik kartı oluşturma fonksiyonu
        // Outer card
        let card = makeCardContainer() // Kart konteyneri oluşturulur

        // Labels
        let titleLabel = UILabel() // Başlık label'ı oluşturulur
        titleLabel.text = title // Başlık metni atanır
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold) // Yazı tipi ve kalınlık ayarlanır
        titleLabel.textColor = .secondaryLabel // Yazı rengi atanır
        titleLabel.textAlignment = .center

        let valueLabel = UILabel() // Değer label'ı oluşturulur
        valueLabel.text = value // Değer metni atanır
        valueLabel.font = .systemFont(ofSize: 20, weight: .semibold) // Yazı tipi ve kalınlık ayarlanır
        valueLabel.textColor = .label // Yazı rengi atanır
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        valueLabel.numberOfLines = 1
        valueLabel.textAlignment = .center

        let labels = UIStackView(arrangedSubviews: [titleLabel, valueLabel]) // Başlık ve değer stack'te birleştirilir
        labels.axis = .vertical
        labels.alignment = .center
        labels.spacing = 4

        // Inner horizontal content without iconWrap
        let inner = UIStackView(arrangedSubviews: [labels]) // Logo yok: daha fazla alan
        inner.axis = .horizontal
        inner.alignment = .center
        inner.spacing = 0
        inner.isLayoutMarginsRelativeArrangement = true
        inner.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        inner.translatesAutoresizingMaskIntoConstraints = false // AutoLayout için autoresizing mask kapatılır

        card.addSubview(inner) // İçerik karta eklenir
        NSLayoutConstraint.activate([ // Kısıtlamalar aktif edilir
            inner.topAnchor.constraint(equalTo: card.topAnchor), // İçerik üstü karta hizalanır
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor), // İçerik sol kenarı karta hizalanır
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor), // İçerik sağ kenarı karta hizalanır
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor), // İçerik altı karta hizalanır
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 64) // Daha dengeli
        ])

        let wrapper = UIStackView(arrangedSubviews: [card]) // Kart bir stack içine alınır
        wrapper.axis = .vertical // Stack dikey hizalanır
        wrapper.alignment = .fill // Elemanlar yatayda doldurulur
        return wrapper // Stack döndürülür
    }
}

// MARK: - Strava-like Detail Full Metrics Overlay
final class RunDetailFullMetricsViewController: UIViewController {

    private weak var source: RunDetailViewController?
    private weak var durRow: UIStackView?
    private weak var paceRow: UIStackView?
    private weak var distRow: UIStackView?
    private weak var kcalRow: UIStackView?

    private var timer: Timer?

    private let timeLabel = UILabel()
    private let paceValueLabel = UILabel()
    private let paceTitleLabel = UILabel()
    private let distValueLabel = UILabel()
    private let distTitleLabel = UILabel()
    private let kcalValueLabel = UILabel()
    private let kcalTitleLabel = UILabel()

    init(source: RunDetailViewController, durRow: UIStackView, paceRow: UIStackView, distRow: UIStackView, kcalRow: UIStackView) {
        self.source = source
        self.durRow = durRow
        self.paceRow = paceRow
        self.distRow = distRow
        self.kcalRow = kcalRow
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 18
        blur.clipsToBounds = true
        view.addSubview(blur)

        // Close button
        let closeBtn = UIButton(type: .system)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setImage(UIImage(systemName: "arrow.down.right.and.arrow.up.left"), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        blur.contentView.addSubview(closeBtn)

        // Styling
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 44, weight: .bold)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .center

        paceValueLabel.translatesAutoresizingMaskIntoConstraints = false
        paceValueLabel.font = .monospacedDigitSystemFont(ofSize: 48, weight: .bold)
        paceValueLabel.textColor = .white
        paceValueLabel.textAlignment = .center
        paceValueLabel.adjustsFontSizeToFitWidth = true
        paceValueLabel.minimumScaleFactor = 0.6

        paceTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        paceTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        paceTitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        paceTitleLabel.textAlignment = .center
        paceTitleLabel.text = "Tempo"

        distValueLabel.translatesAutoresizingMaskIntoConstraints = false
        distValueLabel.font = .monospacedDigitSystemFont(ofSize: 56, weight: .bold)
        distValueLabel.textColor = .white
        distValueLabel.textAlignment = .center
        distValueLabel.adjustsFontSizeToFitWidth = true
        distValueLabel.minimumScaleFactor = 0.6

        distTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        distTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        distTitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        distTitleLabel.textAlignment = .center

        kcalValueLabel.translatesAutoresizingMaskIntoConstraints = false
        kcalValueLabel.font = .monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        kcalValueLabel.textColor = .white
        kcalValueLabel.textAlignment = .center

        kcalTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        kcalTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        kcalTitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        kcalTitleLabel.textAlignment = .center
        kcalTitleLabel.text = "Kalori"

        // Stack
        let stack = UIStackView(arrangedSubviews: [
            timeLabel,
            UIView(),
            paceValueLabel,
            paceTitleLabel,
            UIView(),
            distValueLabel,
            distTitleLabel,
            UIView(),
            kcalValueLabel,
            kcalTitleLabel
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        blur.contentView.addSubview(stack)

        (stack.arrangedSubviews[1] as? UIView)?.heightAnchor.constraint(equalToConstant: 18).isActive = true
        (stack.arrangedSubviews[4] as? UIView)?.heightAnchor.constraint(equalToConstant: 22).isActive = true
        (stack.arrangedSubviews[7] as? UIView)?.heightAnchor.constraint(equalToConstant: 18).isActive = true

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            blur.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            blur.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            closeBtn.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 14),
            closeBtn.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -14),
            closeBtn.widthAnchor.constraint(equalToConstant: 34),
            closeBtn.heightAnchor.constraint(equalToConstant: 34),

            stack.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor)
        ])

        // Subtle app signature (imza)
        let signatureLabel = UILabel()
        signatureLabel.translatesAutoresizingMaskIntoConstraints = false
        signatureLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        signatureLabel.textAlignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .kern: 1.6,
            .foregroundColor: UIColor.appBlue.withAlphaComponent(0.55)
        ]
        signatureLabel.attributedText = NSAttributedString(string: "Stride", attributes: attrs)

        blur.contentView.addSubview(signatureLabel)

        NSLayoutConstraint.activate([
            signatureLabel.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            signatureLabel.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -14)
        ])

        refreshTexts()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshTexts()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func valueText(from row: UIStackView?) -> String? {
        guard let row else { return nil }

        func collectLabels(in view: UIView) -> [UILabel] {
            var out: [UILabel] = []
            if let l = view as? UILabel { out.append(l) }
            if let s = view as? UIStackView {
                for v in s.arrangedSubviews { out.append(contentsOf: collectLabels(in: v)) }
            } else {
                for v in view.subviews { out.append(contentsOf: collectLabels(in: v)) }
            }
            return out
        }

        let labels = collectLabels(in: row)
        // Expected order: title then value
        if labels.count >= 2 { return labels[1].text }
        return labels.first?.text
    }

    private func refreshTexts() {
        // Süre
        timeLabel.text = valueText(from: durRow) ?? "00:00:00"

        // Tempo
        paceValueLabel.text = valueText(from: paceRow) ?? "--:-- /km"

        // Mesafe + unit subtitle
        distValueLabel.text = valueText(from: distRow) ?? "0.00"
        let unitRaw = UserDefaults.standard.string(forKey: "stride.distanceUnit") ?? "kilometers"
        distTitleLabel.text = (unitRaw == "miles") ? "Mesafe (mi)" : "Mesafe (km)"

        // Kalori
        kcalValueLabel.text = valueText(from: kcalRow) ?? "0"
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

