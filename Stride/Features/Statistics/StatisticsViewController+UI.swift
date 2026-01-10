//
//  StatisticsViewController+UI.swift
//  Stride
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır

extension StatisticsViewController { // StatisticsViewController için bir extension başlatır

    // MARK: - UI Setup
    func setupUI() {

        // --- Top toggle (Daily | Statistics) like Groups
        let toggleBar = UIView()
        toggleBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toggleBar)

        let dailyButton = UIButton(type: .system)
        dailyButton.setTitle("Daily", for: .normal)
        dailyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        dailyButton.setTitleColor(.label, for: .normal)
        dailyButton.tintColor = .label
        dailyButton.translatesAutoresizingMaskIntoConstraints = false

        let statsButton = UIButton(type: .system)
        statsButton.setTitle("Statistics", for: .normal)
        statsButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        statsButton.setTitleColor(.label, for: .normal)
        statsButton.tintColor = .label
        statsButton.translatesAutoresizingMaskIntoConstraints = false

        let indicator = UIView()
        indicator.backgroundColor = .label
        indicator.layer.cornerRadius = 1.5
        indicator.translatesAutoresizingMaskIntoConstraints = false

        toggleBar.addSubview(dailyButton)
        toggleBar.addSubview(statsButton)
        toggleBar.addSubview(indicator)

        NSLayoutConstraint.activate([
            toggleBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toggleBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toggleBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toggleBar.heightAnchor.constraint(equalToConstant: 44),

            dailyButton.leadingAnchor.constraint(equalTo: toggleBar.leadingAnchor),
            dailyButton.topAnchor.constraint(equalTo: toggleBar.topAnchor),
            dailyButton.bottomAnchor.constraint(equalTo: toggleBar.bottomAnchor),
            dailyButton.widthAnchor.constraint(equalTo: toggleBar.widthAnchor, multiplier: 0.5),

            statsButton.trailingAnchor.constraint(equalTo: toggleBar.trailingAnchor),
            statsButton.topAnchor.constraint(equalTo: toggleBar.topAnchor),
            statsButton.bottomAnchor.constraint(equalTo: toggleBar.bottomAnchor),
            statsButton.widthAnchor.constraint(equalTo: toggleBar.widthAnchor, multiplier: 0.5),

            indicator.bottomAnchor.constraint(equalTo: toggleBar.bottomAnchor, constant: -2),
            indicator.heightAnchor.constraint(equalToConstant: 3),
            indicator.widthAnchor.constraint(equalTo: toggleBar.widthAnchor, multiplier: 0.5),
            indicator.leadingAnchor.constraint(equalTo: toggleBar.leadingAnchor)
        ])

        // --- Containers
        dailyContainer.translatesAutoresizingMaskIntoConstraints = false
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dailyContainer)
        view.addSubview(statsContainer)

        NSLayoutConstraint.activate([
            dailyContainer.topAnchor.constraint(equalTo: toggleBar.bottomAnchor, constant: 12),
            dailyContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dailyContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dailyContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            statsContainer.topAnchor.constraint(equalTo: toggleBar.bottomAnchor, constant: 12),
            statsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Toggle logic
        func showDaily(_ animated: Bool = true) {
            dailyContainer.isHidden = false
            statsContainer.isHidden = true
            let x: CGFloat = 0
            if animated {
                UIView.animate(withDuration: 0.25) {
                    indicator.transform = CGAffineTransform(translationX: x, y: 0)
                }
            } else {
                indicator.transform = CGAffineTransform(translationX: x, y: 0)
            }
        }

        func showStats(_ animated: Bool = true) {
            dailyContainer.isHidden = true
            statsContainer.isHidden = false
            let x = toggleBar.bounds.width / 2
            if animated {
                UIView.animate(withDuration: 0.25) {
                    indicator.transform = CGAffineTransform(translationX: x, y: 0)
                }
            } else {
                indicator.transform = CGAffineTransform(translationX: x, y: 0)
            }
        }

        dailyButton.addAction(UIAction { _ in showDaily(true) }, for: .touchUpInside)
        statsButton.addAction(UIAction { _ in showStats(true) }, for: .touchUpInside)

        // --- Daily: embed StatisticsDailyViewController
        if !children.contains(where: { $0 is StatisticsDailyViewController }) {
            let dailyVC = StatisticsDailyViewController()
            addChild(dailyVC)
            dailyVC.view.translatesAutoresizingMaskIntoConstraints = false
            dailyContainer.addSubview(dailyVC.view)
            NSLayoutConstraint.activate([
                dailyVC.view.topAnchor.constraint(equalTo: dailyContainer.topAnchor),
                dailyVC.view.leadingAnchor.constraint(equalTo: dailyContainer.leadingAnchor),
                dailyVC.view.trailingAnchor.constraint(equalTo: dailyContainer.trailingAnchor),
                dailyVC.view.bottomAnchor.constraint(equalTo: dailyContainer.bottomAnchor)
            ])
            dailyVC.didMove(toParent: self)
        }

        // --- Stats scroll view goes INSIDE statsContainer
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        statsContainer.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: statsContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statsContainer.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])

        // --- Stats stack
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        contentStack.spacing = 12

        // Header (date range)
        header.axis = .horizontal
        header.alignment = .center
        header.distribution = .fill
        header.spacing = 12

        periodLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        periodLabel.textColor = .label
        periodLabel.textAlignment = .center
        periodLabel.numberOfLines = 2
        periodLabel.setContentHuggingPriority(.required, for: .horizontal)

        // Make sure header is clean
        header.arrangedSubviews.forEach { header.removeArrangedSubview($0); $0.removeFromSuperview() }
        header.addArrangedSubview(periodLabel)

        // Single chart container
        kmChartContainer.translatesAutoresizingMaskIntoConstraints = false
        kmChartContainer.backgroundColor = .secondarySystemBackground
        kmChartContainer.layer.cornerRadius = 16
        kmChartContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

        summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 2

        // Arrange
        contentStack.addArrangedSubview(header)
        contentStack.setCustomSpacing(12, after: header)
        contentStack.addArrangedSubview(kmChartContainer)
        contentStack.addArrangedSubview(summaryLabel)

        // Default: show daily
        showDaily(false)
    }




    // MARK: - Brand Title
    func applyBrandTitle() { // markanın başlığını uygulayan fonksiyon
        // Groups ekranıyla aynı: standart navigation title (renk/font sistemden gelir)
        navigationItem.title = "Statistics"
        navigationItem.titleView = nil

        // Large title kapalı (Groups ile aynı boşluksuz görünüm)
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false
    }
}
