//
//  StatisticsViewController+Chart.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit

// MARK: - StatisticsViewController
final class StatisticsViewController: UIViewController {

    // MARK: - UI
    let header = UIStackView()
    let prevButton = UIButton(type: .system)
    let nextButton = UIButton(type: .system)
    let periodLabel = UILabel()

    let periodControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Hafta", "Ay", "Yıl"])
        sc.selectedSegmentIndex = 0
        return sc
    }()

    let totalLabel = UILabel()
    let scrollView = UIScrollView()
    let contentView = UIView()
    let contentStack = UIStackView()

    // 4 kart
    let kcalCard = UIView()
    let kmCard = UIView()
    let durationCard = UIView()
    let paceCard = UIView()

    let kcalValueLabel = UILabel()
    let kmValueLabel = UILabel()
    let durationValueLabel = UILabel()
    let paceValueLabel = UILabel()
    let summaryLabel = UILabel()

    // 4 grafik container
    let kcalChartContainer = UIView()
    let kmChartContainer = UIView()
    let durationChartContainer = UIView()
    let paceChartContainer = UIView()

    // MARK: - Chart State
    struct ChartState {
        var stacks: [UIStackView] = []
        var bars: [UIView] = []
        var valueLabels: [UILabel] = []
        var dayLabels: [UILabel] = []
        var heightConstraints: [NSLayoutConstraint] = []
    }

    var kcalChart = ChartState()
    var kmChart = ChartState()
    var durationChart = ChartState()
    var paceChart = ChartState()

    // MARK: - State
    enum Period: Int {
        case week = 0
        case month
        case year
    }

    var period: Period = .week
    var weekOffset: Int = 0
    var monthOffset: Int = 0
    var yearOffset: Int = 0

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        applyBrandTitle()
        title = "İstatistikler"
        view.backgroundColor = .systemBackground

        setupUI()
        reloadChart()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleDistanceUnitChanged),
                                               name: .tracklyDistanceUnitDidChange,
                                               object: nil)
    }

    // MARK: - Actions
    @objc func periodChanged(_ sender: UISegmentedControl) {
        guard let newPeriod = Period(rawValue: sender.selectedSegmentIndex) else { return }
        period = newPeriod
        weekOffset = 0
        monthOffset = 0
        yearOffset = 0
        reloadChart()
    }

    @objc func prevPeriod() {
        switch period {
        case .week:  weekOffset -= 1
        case .month: monthOffset -= 1
        case .year:  yearOffset -= 1
        }
        reloadChart()
    }

    @objc func nextPeriod() {
        switch period {
        case .week:  weekOffset += 1
        case .month: monthOffset += 1
        case .year:  yearOffset += 1
        }
        reloadChart()
    }

    // MARK: - Unit Change

    @objc private func handleDistanceUnitChanged() {
        reloadChart()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
