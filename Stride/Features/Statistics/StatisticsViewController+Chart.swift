//
//  StatisticsViewController+UI.swift
//  Stride
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit

// MARK: - StatisticsViewController (Main)
final class StatisticsViewController: UIViewController {

    // MARK: - UI (used by extensions)
    let header = UIStackView()
    let periodLabel = UILabel()

    // MARK: - Mode (Daily / Statistics)
    let modeControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Daily", "Statistics"])
        sc.selectedSegmentIndex = 0 // Default: Daily
        return sc
    }()

    let dailyContainer = UIView()
    let statsContainer = UIView()

    let scrollView = UIScrollView()
    let contentView = UIView()
    let contentStack = UIStackView()

    // Tek grafik container
    let kmChartContainer = UIView()

    // Alt özet
    let summaryLabel = UILabel()

    // MARK: - Actions
    @objc private func modeChanged(_ sender: UISegmentedControl) {
        let isDaily = sender.selectedSegmentIndex == 0
        dailyContainer.isHidden = !isDaily
        statsContainer.isHidden = isDaily
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "İstatistikler"
        view.backgroundColor = .systemBackground

        setupUI()
        modeControl.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        modeChanged(modeControl) // apply default (Daily)

        reloadChart()
    }
}
