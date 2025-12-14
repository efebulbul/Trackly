//
//  RunStore.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import Foundation

final class RunStore {
    static let shared = RunStore()
    private init() { load() }

    private(set) var runs: [Run] = []

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("runs.json")
    }

    func add(_ run: Run) {
        runs.append(run)
        runs.sort { $0.date > $1.date }
        save()
    }

    func delete(id: UUID) {
        runs.removeAll { $0.id == id }
        save()
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(runs)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("RunStore save error:", error)
        }
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Run].self, from: data)
            self.runs = decoded.sorted { $0.date > $1.date }
        } catch {
            self.runs = []
        }
    }

    enum Period: Int, CaseIterable { case day, week, month, year, all }

    func filteredRuns(for period: Period, reference: Date = Date()) -> [Run] {
        switch period {
        case .day:
            let start = Calendar.current.startOfDay(for: reference)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            return runs.filter { $0.date >= start && $0.date < end }

        case .week:
            let cal = Calendar.current
            let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: reference))!
            let end = cal.date(byAdding: .day, value: 7, to: start)!
            return runs.filter { $0.date >= start && $0.date < end }

        case .month:
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: reference)
            let start = cal.date(from: comps)!
            let end = cal.date(byAdding: .month, value: 1, to: start)!
            return runs.filter { $0.date >= start && $0.date < end }

        case .year:
            let cal = Calendar.current
            let comps = cal.dateComponents([.year], from: reference)
            let start = cal.date(from: comps)!
            let end = cal.date(byAdding: .year, value: 1, to: start)!
            return runs.filter { $0.date >= start && $0.date < end }

        case .all:
            return runs
        }
    }
}
