//
//  HistoryViewController+Data.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

extension HistoryViewController {

    func reloadData() {
        let cal = Calendar.current
        let now = Date()

        var start: Date
        var end: Date
        var labelText: String

        switch currentPeriod {
        case .week:
            let base = cal.date(byAdding: .weekOfYear, value: periodOffset, to: now) ?? now
            start = startOfWeek(for: base)
            end = cal.date(byAdding: .day, value: 7, to: start)!

            let df = DateFormatter()
            df.locale = Locale(identifier: "tr_TR")
            df.dateFormat = "d MMM"
            let endLabelDate = cal.date(byAdding: .day, value: 6, to: start)!
            labelText = "\(df.string(from: start)) – \(df.string(from: endLabelDate))"

        case .month:
            let base = cal.date(byAdding: .month, value: periodOffset, to: now) ?? now
            start = startOfMonth(for: base)
            end = cal.date(byAdding: .month, value: 1, to: start)!

            let df = DateFormatter()
            df.locale = Locale(identifier: "tr_TR")
            df.dateFormat = "LLLL yyyy"
            labelText = df.string(from: start).capitalized

        case .year:
            let base = cal.date(byAdding: .year, value: periodOffset, to: now) ?? now
            start = startOfYear(for: base)
            end = cal.date(byAdding: .year, value: 1, to: start)!

            let df = DateFormatter()
            df.locale = Locale(identifier: "tr_TR")
            df.dateFormat = "yyyy"
            labelText = df.string(from: start)

        default:
            start = Date.distantPast
            end = Date.distantFuture
            labelText = ""
        }

        rangeLabel.text = labelText

        #if canImport(FirebaseAuth)
        guard let _ = Auth.auth().currentUser else {
            data = []
            tableView.tableHeaderView = nil
            applyEmptyState()
            tableView.reloadData()
            return
        }

        // Firestore'dan çek - Closure yapısı düzeltildi
        RunFirestoreStore.shared.fetchRuns(completion: { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let runs):
                    self.data = runs
                        .filter { $0.date >= start && $0.date < end }
                        .sorted { $0.date > $1.date }

                    self.tableView.tableHeaderView = nil
                    if self.data.isEmpty {
                        self.applyEmptyState()
                    } else {
                        self.tableView.backgroundView = nil
                    }
                    self.tableView.reloadData()

                case .failure:
                    self.data = []
                    self.tableView.tableHeaderView = nil
                    self.applyEmptyState()
                    self.tableView.reloadData()
                }
            }
        })
        #else
        data = RunStore.shared.runs
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date > $1.date }

        tableView.tableHeaderView = nil
        if data.isEmpty {
            applyEmptyState()
        } else {
            tableView.backgroundView = nil
        }
        tableView.reloadData()
        #endif
    }

    func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? date
    }

    func startOfMonth(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    func startOfYear(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year], from: date)
        return cal.date(from: comps) ?? date
    }
}
