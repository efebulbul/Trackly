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

        // Strava-like padding: rota alt panelin ve tab bar'ın altında kalmasın
        let panelHeight: CGFloat = 200
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
        let bottomInset = view.safeAreaInsets.bottom + panelHeight + tabBarHeight + 16

        // Üstte navigation bar varsa biraz daha nefes alanı bırak
        let topInset: CGFloat = 56

        map.setVisibleMapRect(
            poly.boundingMapRect,
            edgePadding: UIEdgeInsets(top: topInset, left: 40, bottom: bottomInset, right: 40),
            animated: false
        )
    }

    func mapView(_ mapView: MKMapView, // Harita görünümü için overlay render'ı sağlar
                 rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let p = overlay as? MKPolyline { // Overlay bir polyline ise
            let r = MKPolylineRenderer(polyline: p) // Polyline için renderer oluşturur
            r.strokeColor = UIColor(named: "AppBlue") ?? UIColor(red: 0/255.0, green: 107/255.0, blue: 255/255.0, alpha: 1.0) // Tema rengi (fallback: Stride mavisi)
            r.lineWidth = 8 // Çizgi kalınlığını ayarlar
            r.lineJoin = .round // Çizgi birleşim noktalarını yuvarlak yapar
            r.lineCap = .round // Çizgi uçlarını yuvarlak yapar
            return r // Renderer'ı döner
        }
        return MKOverlayRenderer(overlay: overlay) // Diğer overlay türleri için varsayılan renderer döner
    }
}
