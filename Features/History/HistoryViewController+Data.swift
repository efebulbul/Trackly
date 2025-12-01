import Foundation // Temel tarih ve koleksiyon API'lerini içe aktarır

extension HistoryViewController { // HistoryViewController için genişletme başlatır

    func reloadData() { // Verileri yeniden yüklemek için fonksiyon
        let cal = Calendar.current // Varsayılan takvimi kullanır
        let now = Date() // Şu anki tarihi alır

        var start: Date // Başlangıç tarihi için değişken
        var end: Date // Bitiş tarihi için değişken
        var labelText: String // Etiket metni için değişken

        switch currentPeriod { // currentPeriod değerine göre işlem yapar
        case .week: // Eğer dönem hafta ise
            let base = cal.date(byAdding: .weekOfYear, value: periodOffset, to: now) ?? now // Şimdiden periodOffset kadar hafta ekler
            start = startOfWeek(for: base) // Haftanın başlangıç tarihini alır
            end = cal.date(byAdding: .day, value: 7, to: start)! // Başlangıca 7 gün ekleyerek bitiş tarihini belirler

            let df = DateFormatter() // Tarih biçimlendirici oluşturur
            df.locale = Locale(identifier: "tr_TR") // Türkçe yerel ayarını kullanır
            df.dateFormat = "d MMM" // Tarih formatını ayarlar
            let endLabelDate = cal.date(byAdding: .day, value: 6, to: start)! // Haftanın son gününü hesaplar
            labelText = "\(df.string(from: start)) – \(df.string(from: endLabelDate))" // Etiket metnini oluşturur

        case .month: // Eğer dönem ay ise
            let base = cal.date(byAdding: .month, value: periodOffset, to: now) ?? now // Şimdiden periodOffset kadar ay ekler
            start = startOfMonth(for: base) // Ayın başlangıç tarihini alır
            end = cal.date(byAdding: .month, value: 1, to: start)! // Başlangıca 1 ay ekleyerek bitiş tarihini belirler

            let df = DateFormatter() // Tarih biçimlendirici oluşturur
            df.locale = Locale(identifier: "tr_TR") // Türkçe yerel ayarını kullanır
            df.dateFormat = "LLLL yyyy" // Tarih formatını ayarlar
            labelText = df.string(from: start).capitalized // Etiket metnini oluşturur ve baş harfleri büyük yapar

        case .year: // Eğer dönem yıl ise
            let base = cal.date(byAdding: .year, value: periodOffset, to: now) ?? now // Şimdiden periodOffset kadar yıl ekler
            start = startOfYear(for: base) // Yılın başlangıç tarihini alır
            end = cal.date(byAdding: .year, value: 1, to: start)! // Başlangıca 1 yıl ekleyerek bitiş tarihini belirler

            let df = DateFormatter() // Tarih biçimlendirici oluşturur
            df.locale = Locale(identifier: "tr_TR") // Türkçe yerel ayarını kullanır
            df.dateFormat = "yyyy" // Tarih formatını ayarlar
            labelText = df.string(from: start) // Etiket metnini oluşturur

        default: // Diğer durumlar için
            start = Date.distantPast // Çok eski tarihi başlangıç olarak ayarlar
            end = Date.distantFuture // Çok uzak tarihi bitiş olarak ayarlar
            labelText = "" // Etiket metnini boş yapar
        }

        rangeLabel.text = labelText // Etiketin metnini günceller

        data = RunStore.shared.runs // Koşu verilerini alır
            .filter { $0.date >= start && $0.date < end } // Belirtilen tarih aralığında filtreler
            .sorted { $0.date > $1.date } // Tarihe göre azalan sırada sıralar

        tableView.tableHeaderView = nil // Tablo başlık görünümünü kaldırır
        if data.isEmpty { // Eğer veri yoksa
            applyEmptyState() // Boş durum görünümünü uygular
        } else {
            tableView.backgroundView = nil // Arka plan görünümünü temizler
        }
        tableView.reloadData() // Tabloyu yeniden yükler
    }

    func startOfWeek(for date: Date) -> Date { // Haftanın başlangıç tarihini hesaplar
        var cal = Calendar.current // Varsayılan takvimi kullanır
        cal.firstWeekday = 2 // Pazartesi // Haftanın ilk günü Pazartesi olarak ayarlanır
        var start = date // Başlangıç tarihini ayarlar
        var interval: TimeInterval = 0 // Zaman aralığı için değişken
        if cal.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: date) != nil { // Hafta aralığını alır
            return start // Haftanın başlangıç tarihini döner
        }
        return date // Başlangıç tarihi bulunamazsa orijinal tarihi döner
    }

    func startOfMonth(for date: Date) -> Date { // Ayın başlangıç tarihini hesaplar
        let cal = Calendar.current // Varsayılan takvimi kullanır
        let comps = cal.dateComponents([.year, .month], from: date) // Yıl ve ay bileşenlerini alır
        return cal.date(from: comps) ?? date // Bu bileşenlerden tarih oluşturur, başarısızsa orijinal tarihi döner
    }

    func startOfYear(for date: Date) -> Date { // Yılın başlangıç tarihini hesaplar
        let cal = Calendar.current // Varsayılan takvimi kullanır
        let comps = cal.dateComponents([.year], from: date) // Yıl bileşenini alır
        return cal.date(from: comps) ?? date // Bu bileşenden tarih oluşturur, başarısızsa orijinal tarihi döner
    }
}
