//
//  StatisticsDailyViewController.swift
//  Stride
//
//  Created by EfeBülbül on 10.01.2026.
//

import UIKit
import SwiftUI
import Charts

final class StatisticsDailyViewController: UIViewController {

    private var hostingController: UIHostingController<StatisticsDailyDashboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let host = UIHostingController(rootView: StatisticsDailyDashboardView())
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        host.didMove(toParent: self)
        hostingController = host
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let tabBar = tabBarController?.tabBar else { return }

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - SwiftUI (Daily Dashboard)

@MainActor
final class StatisticsDailyDashboardViewModel: ObservableObject {

    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil

    @Published var activeEnergyKcal: Double = 0
    @Published var energyGoalKcal: Double = 280
    @Published var hourlyEnergy: [HealthKitManager.HourlyStat] = (0...23).map { .init(hour: $0, value: 0) }

    @Published var steps: Double = 0
    @Published var hourlySteps: [HealthKitManager.HourlyStat] = (0...23).map { .init(hour: $0, value: 0) }

    @Published var distanceKm: Double = 0
    @Published var hourlyDistance: [HealthKitManager.HourlyStat] = (0...23).map { .init(hour: $0, value: 0) }

    func onAppear() {
        HealthKitManager.shared.requestAuthorization { [weak self] success, error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = error.localizedDescription
                }
                if success {
                    self?.reload()
                } else {
                    self?.isLoading = false
                }
            }
        }
    }

    func reload() {
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()
        var firstError: Error?

        group.enter()
        HealthKitManager.shared.fetchTodayActiveEnergyKcal { [weak self] result in
            defer { group.leave() }
            switch result {
            case .success(let v): DispatchQueue.main.async { self?.activeEnergyKcal = v }
            case .failure(let e): firstError = firstError ?? e
            }
        }

        group.enter()
        HealthKitManager.shared.fetchHourlyActiveEnergyKcalToday { [weak self] result in
            defer { group.leave() }
            switch result {
            case .success(let v): DispatchQueue.main.async { self?.hourlyEnergy = v }
            case .failure(let e): firstError = firstError ?? e
            }
        }

        group.enter()
        HealthKitManager.shared.fetchTodaySteps { [weak self] result in
            defer { group.leave() }
            switch result {
            case .success(let v): DispatchQueue.main.async { self?.steps = v }
            case .failure(let e): firstError = firstError ?? e
            }
        }

        group.enter()
        HealthKitManager.shared.fetchHourlyStepsToday { [weak self] result in
            defer { group.leave() }
            switch result {
            case .success(let v): DispatchQueue.main.async { self?.hourlySteps = v }
            case .failure(let e): firstError = firstError ?? e
            }
        }

        group.enter()
        HealthKitManager.shared.fetchTodayDistanceKm { [weak self] result in
            defer { group.leave() }
            switch result {
            case .success(let v): DispatchQueue.main.async { self?.distanceKm = v }
            case .failure(let e): firstError = firstError ?? e
            }
        }

        group.enter()
        HealthKitManager.shared.fetchHourlyDistanceKmToday { [weak self] result in
            defer { group.leave() }
            switch result {
            case .success(let v): DispatchQueue.main.async { self?.hourlyDistance = v }
            case .failure(let e): firstError = firstError ?? e
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            if let firstError {
                self?.errorMessage = firstError.localizedDescription
            }
        }
    }

    var energyProgress: Double {
        guard energyGoalKcal > 0 else { return 0 }
        return min(max(activeEnergyKcal / energyGoalKcal, 0), 1)
    }

    var stepsText: String {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        return n.string(from: NSNumber(value: Int(steps.rounded()))) ?? String(Int(steps.rounded()))
    }

    var distanceText: String {
        String(format: "%.2f km", distanceKm)
    }

    var todayText: String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "d MMM EEEE"
        return df.string(from: Date()).uppercased()
    }
}

struct StatisticsDailyDashboardView: View {

    @StateObject private var vm = StatisticsDailyDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.todayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Summary")
                        .font(.system(size: 34, weight: .bold))
                }

                StatisticsDailyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            StatisticsDailyActivityRing(progress: vm.energyProgress)
                                .frame(width: 110, height: 110)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Calories")
                                    .font(.headline)

                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(Int(vm.activeEnergyKcal.rounded()))")
                                        .font(.system(size: 34, weight: .bold))
                                    Text("/\(Int(vm.energyGoalKcal.rounded()))")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }

                                Text("kcal")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }

                        Chart(vm.hourlyEnergy) { p in
                            BarMark(
                                x: .value("Hour", p.hour),
                                y: .value("kcal", p.value)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: [0, 6, 12, 18, 23])
                        }
                        .frame(height: 140)
                    }
                }

                HStack(spacing: 12) {
                    StatisticsDailyMetricCard(
                        title: "Step Count",
                        subtitle: "Today",
                        value: vm.stepsText,
                        valueColor: .purple,
                        series: vm.hourlySteps
                    )

                    StatisticsDailyMetricCard(
                        title: "Step Distance",
                        subtitle: "Today",
                        value: vm.distanceText,
                        valueColor: .blue,
                        series: vm.hourlyDistance
                    )
                }

                StatisticsDailyCard {
                    HStack {
                        Text("Rewards")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer().frame(height: 12)

                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(.tertiarySystemFill))
                            Image(systemName: "rosette")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 64, height: 64)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("No rewards yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Complete goals to earn badges")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer(minLength: 0)
                    }
                }

                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }

                if let msg = vm.errorMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .onAppear { vm.onAppear() }
        .refreshable { vm.reload() }
    }
}

struct StatisticsDailyCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct StatisticsDailyActivityRing: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 18)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.red, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
        }
    }
}

struct StatisticsDailyMetricCard: View {
    let title: String
    let subtitle: String
    let value: String
    let valueColor: Color
    let series: [HealthKitManager.HourlyStat]

    var body: some View {
        StatisticsDailyCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(valueColor)

                StatisticsDailyHourlyMiniChart(points: series)
                    .frame(height: 54)
            }
        }
    }
}

struct StatisticsDailyHourlyMiniChart: View {
    let points: [HealthKitManager.HourlyStat]

    var body: some View {
        Chart(points) { p in
            BarMark(
                x: .value("Hour", p.hour),
                y: .value("Value", p.value),
                width: .fixed(4)
            )
        }
        .chartXScale(domain: 0...23)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisTick().foregroundStyle(.secondary)
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text("\(hour)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
    }
}
