import UIKit
import UserNotifications

final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private enum Section: Int, CaseIterable {
        case profile
        case settings
    }

    private enum SettingsRow: Int, CaseIterable {
        case premium
        case notifications
        case language
        case theme
        case about
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Ayarlar"
        view.backgroundColor = .systemBackground

        // TableView setup
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .systemGroupedBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = Section(rawValue: section) else { return 0 }
        switch sec {
        case .profile:
            return 1
        case .settings:
            return SettingsRow.allCases.count
        }
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        guard let section = Section(rawValue: indexPath.section) else { return cell }

        switch section {
        case .profile:
            // Profil satırı
            config.text = "Kullanıcı adı"
            config.image = UIImage(systemName: "person.circle.fill")
            config.imageProperties.preferredSymbolConfiguration =
                UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
            config.imageProperties.tintColor = UIColor(red: 0/255, green: 107/255, blue: 255/255, alpha: 1.0)
            cell.selectionStyle = .none

        case .settings:
            let tracklyBlue = UIColor(red: 0/255, green: 107/255, blue: 255/255, alpha: 1.0)

            guard let row = SettingsRow(rawValue: indexPath.row) else { return cell }
            cell.accessoryType = .disclosureIndicator

            switch row {
            case .premium:
                config.image = UIImage(systemName: "figure.run")
                config.imageProperties.tintColor = tracklyBlue
                config.text = "Trackly Premium"
                config.secondaryText = "Gelişmiş istatistikler ve daha fazlası"

            case .notifications:
                config.text = "Bildirimler"
                config.image = UIImage(systemName: "bell.badge.fill")
                config.imageProperties.tintColor = tracklyBlue
                config.secondaryText = "Durum kontrol ediliyor..."
                config.secondaryTextProperties.color = .secondaryLabel

                // Mevcut izin durumuna göre alt metni güncelle
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        guard let visibleCell = tableView.cellForRow(at: indexPath) else { return }
                        var cfg = visibleCell.defaultContentConfiguration()
                        cfg.text = "Bildirimler"
                        cfg.image = UIImage(systemName: "bell.badge.fill")
                        cfg.imageProperties.preferredSymbolConfiguration =
                            UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
                        cfg.imageProperties.tintColor = tracklyBlue

                        switch settings.authorizationStatus {
                        case .authorized, .provisional:
                            cfg.secondaryText = "Açık"
                            cfg.secondaryTextProperties.color = .systemGreen
                        case .denied:
                            cfg.secondaryText = "Kapalı"
                            cfg.secondaryTextProperties.color = .systemRed
                        case .notDetermined:
                            fallthrough
                        @unknown default:
                            cfg.secondaryText = "Henüz sorulmadı"
                            cfg.secondaryTextProperties.color = .secondaryLabel
                        }

                        visibleCell.contentConfiguration = cfg
                    }
                }

            case .language:
                config.text = "Dil"
                config.secondaryText = "Cihaz dili"
                config.image = UIImage(systemName: "globe")
                config.imageProperties.tintColor = tracklyBlue

            case .theme:
                config.text = "Tema"
                config.secondaryText = currentThemeTitle()
                config.image = UIImage(systemName: "paintpalette")
                config.imageProperties.tintColor = tracklyBlue

            case .about:
                config.text = "Hakkında"
                config.secondaryText = "Trackly"
                config.image = UIImage(systemName: "info.circle")
                config.imageProperties.tintColor = tracklyBlue
            }

            config.imageProperties.preferredSymbolConfiguration =
                UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        }

        cell.contentConfiguration = config

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .secondarySystemGroupedBackground
        cell.backgroundConfiguration = bg
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = true

        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .profile:
            // Şimdilik tıklayınca bir şey yapma
            break

        case .settings:
            guard let row = SettingsRow(rawValue: indexPath.row) else { return }
            switch row {
            case .premium:
                let alert = UIAlertController(
                    title: "Trackly Premium",
                    message: "Premium özellikler yakında eklenecek.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Tamam", style: .default))
                present(alert, animated: true)

            case .notifications:
                requestDailyMotivationNotification()

            case .language:
                let alert = UIAlertController(
                    title: "Dil",
                    message: "Dil ayarları daha sonra eklenecek.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Tamam", style: .default))
                present(alert, animated: true)

            case .theme:
                presentThemePicker()

            case .about:
                let alert = UIAlertController(
                    title: "Trackly",
                    message: "Koşu ve istatistik uygulaması.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Tamam", style: .default))
                present(alert, animated: true)
            }
        }
    }

    // MARK: - Tema

    private func currentThemeTitle() -> String {
        let style = view.window?.overrideUserInterfaceStyle ?? traitCollection.userInterfaceStyle
        switch style {
        case .dark: return "Koyu"
        case .light: return "Açık"
        default: return "Sistem"
        }
    }

    private func presentThemePicker() {
        let ac = UIAlertController(title: "Tema", message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: "Sistem", style: .default, handler: { _ in
            self.setTheme(.unspecified)
        }))
        ac.addAction(UIAlertAction(title: "Açık", style: .default, handler: { _ in
            self.setTheme(.light)
        }))
        ac.addAction(UIAlertAction(title: "Koyu", style: .default, handler: { _ in
            self.setTheme(.dark)
        }))
        ac.addAction(UIAlertAction(title: "İptal", style: .cancel))

        if let pop = ac.popoverPresentationController {
            pop.sourceView = self.view
            pop.sourceRect = CGRect(x: self.view.bounds.midX,
                                    y: self.view.bounds.midY,
                                    width: 0,
                                    height: 0)
        }

        present(ac, animated: true)
    }

    private func setTheme(_ style: UIUserInterfaceStyle) {
        // Uygulamanın tüm pencerelerine uygula
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = style }

        tableView.reloadData()
    }

    // MARK: - Daily Motivation Notification

    private let dailyMotivationIdentifier = "trackly.daily.motivation.08"

    private func requestDailyMotivationNotification() {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.scheduleDailyMotivationNotification()

                case .notDetermined:
                    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self.showSimpleAlert(title: "Bildirimler", message: error.localizedDescription)
                                return
                            }
                            if granted {
                                self.scheduleDailyMotivationNotification()
                            } else {
                                self.showSimpleAlert(
                                    title: "Bildirimler",
                                    message: "Bildirim izni verilmedi."
                                )
                            }
                        }
                    }

                case .denied:
                    self.showSimpleAlert(
                        title: "Bildirimler",
                        message: "Bildirim izni kapalı. Ayarlar uygulamasından açabilirsin."
                    )

                @unknown default:
                    break
                }
            }
        }
    }

    private func scheduleDailyMotivationNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyMotivationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Trackly"
        content.body = "Bugün için bir koşu planladın mı? Hedeflerine doğru bir adım at! 🏃‍♂️"
        content.sound = .default

        var components = DateComponents()
        components.hour = 8
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: dailyMotivationIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showSimpleAlert(title: "Bildirimler", message: error.localizedDescription)
                } else {
                    self.showSimpleAlert(
                        title: "Bildirimler",
                        message: "Her sabah 08:00'de koşu motivasyon bildirimi alacaksın."
                    )
                }
            }
        }
    }

    private func showSimpleAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(ac, animated: true)
    }
}
