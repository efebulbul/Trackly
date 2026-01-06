//
//  RunViewController+Location.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit // UIKit framework'ünü içe aktarır
import CoreLocation // CoreLocation framework'ünü içe aktarır
import MapKit // MapKit framework'ünü içe aktarır

// MARK: - Permission & Alerts

extension RunViewController { // RunViewController için extension başlatır

    func currentAuthStatus() -> CLAuthorizationStatus { // Mevcut konum yetki durumunu döner
        if #available(iOS 14.0, *) { // iOS 14 ve üzeri kontrolü yapar
            return locationManager.authorizationStatus // Yeni API ile yetki durumunu döner
        } else {
            return CLLocationManager.authorizationStatus() // Eski API ile yetki durumunu döner
        }
    }

    func showLocationServicesDisabledAlert() { // Konum servisleri kapalı uyarısını gösterir
        let alert = UIAlertController( // UIAlertController oluşturur
            title: "Konum Servisleri Kapalı", // Başlık ayarlar
            message: "Koşu takibi için Konum Servisleri açık olmalı. Ayarlar > Gizlilik ve Güvenlik > Konum Servisleri'ni aç.", // Mesaj ayarlar
            preferredStyle: .alert // Stil alert olarak belirler
        )
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel, handler: nil)) // İptal butonu ekler
        alert.addAction(UIAlertAction(title: "Ayarlar", style: .default, handler: { _ in // Ayarlar butonu ekler
            if let url = URL(string: UIApplication.openSettingsURLString), // Ayarlar URL'sini oluşturur
               UIApplication.shared.canOpenURL(url) { // URL açılabilir mi kontrol eder
                UIApplication.shared.open(url, options: [:], completionHandler: nil) // Ayarlar uygulamasını açar
            }
        }))
        present(alert, animated: true, completion: nil) // Alert'i gösterir
    }

    func showLocationDeniedAlert() { // Konum izni reddedildi uyarısını gösterir
        let alert = UIAlertController( // UIAlertController oluşturur
            title: "Konum İzni Gerekli", // Başlık ayarlar
            message: "Koşu takibi için konum erişimine izin vermen gerekiyor. Ayarlar'dan izin verebilirsin.", // Mesaj ayarlar
            preferredStyle: .alert // Stil alert olarak belirler
        )
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel, handler: nil)) // İptal butonu ekler
        alert.addAction(UIAlertAction(title: "Ayarlar", style: .default, handler: { _ in // Ayarlar butonu ekler
            if let url = URL(string: UIApplication.openSettingsURLString), // Ayarlar URL'sini oluşturur
               UIApplication.shared.canOpenURL(url) { // URL açılabilir mi kontrol eder
                UIApplication.shared.open(url, options: [:], completionHandler: nil) // Ayarlar uygulamasını açar
            }
        }))
        present(alert, animated: true, completion: nil) // Alert'i gösterir
    }
}

// MARK: - CLLocationManagerDelegate

extension RunViewController: CLLocationManagerDelegate { // CLLocationManagerDelegate protokolünü uygular

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { // Yetki durumu değiştiğinde çağrılır
        switch manager.authorizationStatus { // Yetki durumuna göre işlem yapar
        case .authorizedWhenInUse: // Uygulama kullanılırken izin verildiğinde
            // When-In-Use alındı → Always iste (bir kez ve Info.plist anahtarı varsa)
            if !askedAlwaysOnce { // Daha önce Always izni istenmediyse
                askedAlwaysOnce = true // İzin istenmiş olarak işaretle
                if hasPlistKey("NSLocationAlwaysAndWhenInUseUsageDescription") { // Info.plist anahtarı varsa
                    manager.requestAlwaysAuthorization() // Always izni ister
                }
            }
            fallthrough // Bir sonraki case'e geçer

        case .authorizedAlways: // Her zaman izin verildiğinde
            mapView.showsUserLocation = true // Haritada kullanıcı konumu gösterilir
            manager.startUpdatingLocation() // Konum güncellemeleri başlatılır

        case .denied, .restricted: // İzin reddedildi veya kısıtlandıysa
            showLocationDeniedAlert() // İzin reddedildi uyarısı gösterilir

        case .notDetermined: // Henüz izin durumu belirlenmediyse
            break // İşlem yapmaz

        @unknown default: // Bilinmeyen durumlar için
            break // İşlem yapmaz
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { // Konum güncellendiğinde çağrılır
        guard let loc = locations.last else { return } // Son konumu alır, yoksa çıkış yapar

        // Zayıf doğruluk verilerini at (accuracy > 20m veya negatif)
        if loc.horizontalAccuracy < 0 || loc.horizontalAccuracy > 20 { // Doğruluk 0'dan küçük veya 20'den büyükse
            return // İşlem yapmaz
        }

        if !hasCenteredOnUser { // Henüz kullanıcıya merkezlenmediyse
            let region = MKCoordinateRegion( // Harita bölgesi oluşturur
                center: loc.coordinate, // Merkez olarak kullanıcı konumu
                latitudinalMeters: 800, // 800 metre enlem
                longitudinalMeters: 800 // 800 metre boylam
            )
            mapView.setRegion(region, animated: true) // Haritayı bu bölgeye kaydırır
            hasCenteredOnUser = true // Merkezlenme durumu true yapılır
        }

        // Mesafe biriktirme
        if isRunning { // Koşu aktifse
            let current = loc // Güncel konumu alır
            if let last = lastCoordinate { // Önceki konum varsa
                let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude) // Önceki konumu CLLocation olarak oluşturur
                let delta = current.distance(from: lastLoc) // meters // İki konum arasındaki mesafeyi hesaplar
                // Gürültü filtreleri: min 5m adım, 30m üzeri sıçramaları at
                if delta >= 5 && delta <= 30 { // Mesafe 5 ile 30 metre arasındaysa
                    totalDistanceMeters += delta // Toplam mesafeye ekler
                }
            }
            lastCoordinate = current.coordinate // Son konumu günceller
            appendCoordinate(loc.coordinate) // Rota noktasını ekler
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { // Konum hatası oluştuğunda çağrılır
        print("Location error:", error.localizedDescription) // Hata mesajını yazdırır
    }

    // Rota noktasını ekle ve overlay'i güncelle
    func appendCoordinate(_ coord: CLLocationCoordinate2D) { // Yeni koordinat ekler
        // Gürültüyü azalt: son noktaya çok yakınsa ekleme (5 m eşiği)
        if let last = routeCoords.last { // Son rota noktası varsa
            let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude) // Son noktayı CLLocation yapar
            let newLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude) // Yeni koordinatı CLLocation yapar
            if newLoc.distance(from: lastLoc) < 5 { return } // 5 metreden yakınsa ekleme
        }
        routeCoords.append(coord) // Koordinatı rotaya ekler
        updateRouteOverlay() // Rota çizgisini günceller
    }

    func updateRouteOverlay() { // Rota çizgisini günceller
        if let poly = routePolyline { // Önceki polyline varsa
            mapView.removeOverlay(poly) // Haritadan kaldırır
        }
        let polyline = MKPolyline(coordinates: routeCoords, count: routeCoords.count) // Yeni polyline oluşturur
        routePolyline = polyline // Polyline referansını günceller
        mapView.addOverlay(polyline) // Haritaya polyline ekler
    }
}

// MARK: - MKMapViewDelegate

extension RunViewController: MKMapViewDelegate { // MKMapViewDelegate protokolünü uygular
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer { // Overlay için renderer sağlar
        if let polyline = overlay as? MKPolyline { // Overlay polyline ise
            let r = MKPolylineRenderer(polyline: polyline) // Polyline renderer oluşturur
            r.strokeColor = UIColor(named: "AppBlue") ?? UIColor(red: 0/255, green: 107/255, blue: 255/255, alpha: 1.0) // Çizgi rengi (fallback dahil)
            r.lineWidth = 8 // Çizgi kalınlığını ayarlar
            r.lineJoin = .round // Köşe birleşimini yuvarlak yapar
            r.lineCap = .round // Çizgi uçlarını yuvarlak yapar
            r.alpha = 0.95 // Saydamlık ayarlar
            return r // Renderer döner
        }
        return MKOverlayRenderer(overlay: overlay) // Diğer overlayler için varsayılan renderer döner
    }
}
