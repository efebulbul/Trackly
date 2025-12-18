//
//  Coord.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import CoreLocation

struct Coord: Codable, Hashable {
    let lat: Double
    let lng: Double

    // Init from raw values
    init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }

    // Init from CLLocationCoordinate2D
    init(_ c: CLLocationCoordinate2D) {
        self.lat = c.latitude
        self.lng = c.longitude
    }

    // Back to CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
