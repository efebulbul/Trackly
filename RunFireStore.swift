//
//  RunFireStore.swift
//  Trackly
//
//  Created by EfeBülbül on 18.12.2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

final class RunFirestoreStore {
    static let shared = RunFirestoreStore()
    private init() {}

    private let db = Firestore.firestore()

    private var uid: String {
        guard let u = Auth.auth().currentUser?.uid else {
            fatalError("User must be logged in.")
        }
        return u
    }

    private var runsCol: CollectionReference {
        db.collection("users").document(uid).collection("runs")
    }

    func addRun(_ run: Run, steps: Int, completion: ((Error?) -> Void)? = nil) {
        let docId = run.id.uuidString

        let routeArray: [[String: Double]] = run.route.map { c in
            ["lat": c.lat, "lng": c.lng]
        }

        let data: [String: Any] = [
            "name": run.name,
            "date": Timestamp(date: run.date),
            "durationSeconds": run.durationSeconds,
            "distanceMeters": run.distanceMeters,
            "calories": run.calories,
            "steps": steps,
            "route": routeArray
        ]

        runsCol.document(docId).setData(data, merge: true, completion: completion)
    }

    func fetchRuns(completion: @escaping (Result<[Run], Error>) -> Void) {
        runsCol.order(by: "date", descending: true).getDocuments { snap, err in
            if let err = err { completion(.failure(err)); return }

            let runs: [Run] = snap?.documents.compactMap { doc in
                let d = doc.data()

                guard
                    let name = d["name"] as? String,
                    let ts = d["date"] as? Timestamp,
                    let duration = d["durationSeconds"] as? Int,
                    let distance = d["distanceMeters"] as? Double,
                    let calories = d["calories"] as? Double
                else { return nil }

                let routeAny = d["route"] as? [[String: Double]] ?? []
                let coords: [CLLocationCoordinate2D] = routeAny.compactMap { item in
                    guard let lat = item["lat"], let lng = item["lng"] else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }

                return Run(
                    name: name,
                    date: ts.dateValue(),
                    durationSeconds: duration,
                    distanceMeters: distance,
                    calories: calories,
                    route: coords
                )
            } ?? []

            completion(.success(runs))
        }
    }

    func deleteRun(runId: UUID, completion: ((Error?) -> Void)? = nil) {
        runsCol.document(runId.uuidString).delete(completion: completion)
    }
}
