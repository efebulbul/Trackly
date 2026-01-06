//
//  Run.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import Foundation
import CoreLocation

struct Run: Codable, Hashable {
    let id: UUID
    let name: String
    let date: Date
    let durationSeconds: Int
    let distanceMeters: Double
    let calories: Double
    let route: [Coord]
    
    init(
        name: String,
        date: Date,
        durationSeconds: Int,
        distanceMeters: Double,
        calories: Double,
        route: [CLLocationCoordinate2D]
    ) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.calories = calories
        self.route = route.map { Coord($0) }
    }
    
    var distanceKm: Double {
        distanceMeters / 1000.0
    }
    
    var avgPaceSecPerKm: Double {
        distanceKm > 0 ? Double(durationSeconds) / distanceKm : 0
    }
    
    
    // Firestore/Storage gibi yerlerden okurken ID'yi korumak için
    init(
        id: UUID,
        name: String,
        date: Date,
        durationSeconds: Int,
        distanceMeters: Double,
        calories: Double,
        route: [CLLocationCoordinate2D]
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.calories = calories
        self.route = route.map { Coord($0) }
    }
}
