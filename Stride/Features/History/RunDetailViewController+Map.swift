//
//  RunDetailViewController+Map.swift
//  Stride
//
//  Created by EfeBülbül on 5.11.2025.
//

import MapKit // Harita ve rota çizimi için MapKit framework'ünü içe aktarır

extension RunDetailViewController: MKMapViewDelegate { // RunDetailViewController'a MKMapViewDelegate protokolünü uygular

    func drawRoute() { // Koşu rotasını harita üzerinde çizen fonksiyon
        let coords = run.route.map { $0.coordinate } // Koşu rotasındaki tüm koordinatları çıkarır
        guard coords.count >= 2 else { return } // En az iki koordinat yoksa fonksiyondan çıkar
        let poly = MKPolyline(coordinates: coords, count: coords.count) // Koşu rotasını temsil eden polyline oluşturur
        map.addOverlay(poly) // Haritaya polyline katmanını ekler
        map.setVisibleMapRect( // Harita görünümünü polyline'ın kapsadığı alana göre ayarlar
            poly.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), // Harita kenar boşluklarını ayarlar
            animated: false // Harita animasyonu olmadan ayarlanır
        )
    }

    func mapView(_ mapView: MKMapView, // Harita görünümü için overlay render'ı sağlar
                 rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let p = overlay as? MKPolyline { // Overlay bir polyline ise
            let r = MKPolylineRenderer(polyline: p) // Polyline için renderer oluşturur
            r.strokeColor = UIColor(hex: "#006BFF") // Çizgi rengini belirler
            r.lineWidth = 8 // Çizgi kalınlığını ayarlar
            r.lineJoin = .round // Çizgi birleşim noktalarını yuvarlak yapar
            r.lineCap = .round // Çizgi uçlarını yuvarlak yapar
            return r // Renderer'ı döner
        }
        return MKOverlayRenderer(overlay: overlay) // Diğer overlay türleri için varsayılan renderer döner
    }
}
