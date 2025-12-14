//
//  Coord.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import CoreLocation

struct Coord: Codable, Hashable {
    let lat: Double
    let lon: Double

    init(_ c: CLLocationCoordinate2D) {
        self.lat = c.latitude
        self.lon = c.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
