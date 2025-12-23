//
//  SettingsViewController
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit
import UserNotifications

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif


final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private enum Section: Int, CaseIterable {
        case profile
        case settings
    }

    private enum SettingsRow: Int, CaseIterable {
        case dailyReminder
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "profileCell")

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
            return buildProfileSummaryCell(tableView)

        case .settings:
            guard let row = SettingsRow(rawValue: indexPath.row) else { return cell }

            // default cell behaviour (override per-row)
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

            switch row {

            case .dailyReminder:
                config.text = "Bildirimler"
                config.image = UIImage(systemName: "alarm")
                config.imageProperties.tintColor = .tracklyBlue
                config.secondaryText = "Her gün saat 08:00'te hatırlatma al."
                config.secondaryTextProperties.color = .secondaryLabel

                let sw = UISwitch()
                sw.isOn = UserDefaults.standard.bool(forKey: dailyReminderKey)
                sw.onTintColor = .tracklyBlue
                sw.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    let enabled = sw.isOn
                    UserDefaults.standard.set(enabled, forKey: self.dailyReminderKey)
                    if enabled {
                        self.enableDailyReminder()
                    } else {
                        self.cancelDailyReminder()
                    }
                }, for: .valueChanged)

                cell.accessoryView = sw
                cell.accessoryType = .none
                cell.selectionStyle = .none

            case .notifications:
                config.text = "Bildirim İzni"
                config.image = UIImage(systemName: "bell.badge.fill")
                config.imageProperties.tintColor = .tracklyBlue
                config.secondaryText = "Durum kontrol ediliyor..."
                config.secondaryTextProperties.color = .secondaryLabel

                // Mevcut izin durumuna göre alt metni güncelle
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        guard let visibleCell = tableView.cellForRow(at: indexPath) else { return }
                        var cfg = visibleCell.defaultContentConfiguration()
                        cfg.text = "Bildirim İzni"
                        cfg.image = UIImage(systemName: "bell.badge")
                        cfg.imageProperties.preferredSymbolConfiguration =
                            UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
                        cfg.imageProperties.tintColor = .tracklyBlue

                        switch settings.authorizationStatus {
                        case .authorized, .provisional:
                            cfg.secondaryText = "Açık"
                            cfg.secondaryTextProperties.color = .systemGreen

                        case .denied:
                            cfg.secondaryText = "Kapalı"
                            cfg.secondaryTextProperties.color = .systemRed

                        case .ephemeral:
                            cfg.secondaryText = "Sınırlı"
                            cfg.secondaryTextProperties.color = .systemGreen

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
                config.imageProperties.tintColor = .tracklyBlue

            case .theme:
                config.text = "Tema"
                config.secondaryText = currentThemeTitle()
                config.image = UIImage(systemName: "paintpalette")
                config.imageProperties.tintColor = .tracklyBlue

            case .about:
                config.text = "Hakkında"
                config.secondaryText = "v1.0"
                config.image = UIImage(systemName: "info.circle")
                config.imageProperties.tintColor = .tracklyBlue
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
            #if canImport(FirebaseAuth)
            if Auth.auth().currentUser != nil {
                presentProfilePanel()
            } else {
                presentLogin()
            }
            #else
            presentLogin()
            #endif

        case .settings:
            guard let row = SettingsRow(rawValue: indexPath.row) else { return }
            switch row {

            case .dailyReminder:
                // switch ile yönetiliyor
                break

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
                    title: "Hakkında",
                    message: "Trackly v1.0                                            Trackly kullandığın için teşekkürler!",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Tamam", style: .default))
                present(alert, animated: true)
            }
        }
    }


    // MARK: - Profile (Taskly tarzı)

    private var cachedDisplayName: String?
    private var cachedEmail: String?

    /// Profil özet hücresi: avatar + ad. (Main hücrede mail yok.)
    func buildProfileSummaryCell(_ tableView: UITableView) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "profileCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "profileCell")
        var cfg = UIListContentConfiguration.subtitleCell()

        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            cachedDisplayName = user.displayName
            cachedEmail = user.email

            cfg.text = resolvedDisplayName()
            cfg.secondaryText = "" // mail görünmesin
            cfg.image = UIImage(systemName: "person.circle.fill")
            cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            cfg.imageProperties.tintColor = .tracklyBlue
            cell.accessoryView = nil
        } else {
            cfg.text = "Giriş Yap"
            cfg.secondaryText = "Hesabınla giriş yap"
            cfg.image = UIImage(systemName: "person.crop.circle")
            cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            cfg.imageProperties.tintColor = .tracklyBlue
            cell.accessoryView = nil
        }
        #else
        cfg.text = "Giriş Yap"
        cfg.secondaryText = "Hesabınla giriş yap"
        cfg.image = UIImage(systemName: "person.crop.circle")
        cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        cfg.imageProperties.tintColor = .tracklyBlue
        #endif

        cfg.textProperties.font = .preferredFont(forTextStyle: .headline)
        cfg.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = cfg

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .secondarySystemGroupedBackground
        cell.backgroundConfiguration = bg
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = true

        // Seçilebilir kalsın (didSelect ile panel açacağız)
        cell.selectionStyle = .default

        return cell
    }

    /// İsim çözümü: Auth.displayName → email prefix → fallback
    func resolvedDisplayName() -> String {
        #if canImport(FirebaseAuth)
        if let authName = Auth.auth().currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !authName.isEmpty {
            return authName
        }
        let authEmail = Auth.auth().currentUser?.email
        #else
        let authEmail: String? = nil
        #endif

        if let cached = cachedDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), !cached.isEmpty {
            return cached
        }

        let email = cachedEmail ?? authEmail
        if let local = email?.split(separator: "@").first, !local.isEmpty {
            // "efe.bulbul" -> "Efe Bulbul"
            return String(local).replacingOccurrences(of: ".", with: " ").capitalized
        }

        return "Bilinmiyor"
    }

    // MARK: - Profile Panel (sheet)

    @objc func presentProfilePanel() {
        let panel = ProfilePanelViewController()
        panel.host = self
        panel.displayName = resolvedDisplayName()
        #if canImport(FirebaseAuth)
        panel.email = Auth.auth().currentUser?.email
        #else
        panel.email = cachedEmail
        #endif

        // IMPORTANT: set presentation style before reading sheetPresentationController
        panel.modalPresentationStyle = .pageSheet

        if let sheet = panel.sheetPresentationController {
            // Taskly-like: allow dragging between medium and large
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true

            // Keep the drag feeling on the sheet (not the table scroll)
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true

            // Optional, but usually helps match the iOS sheet feel
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }

        present(panel, animated: true)
    }

    func presentLogin() {
        let login = LoginViewController()
        login.modalPresentationStyle = .fullScreen
        present(login, animated: true)
    }

    func presentSignOutConfirm() {
        let ac = UIAlertController(title: "Çıkış Yap", message: "Çıkış yapmak istiyor musun?", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "İptal", style: .cancel))
        ac.addAction(UIAlertAction(title: "Çıkış Yap", style: .destructive, handler: { [weak self] _ in
            self?.performSignOut()
        }))
        present(ac, animated: true)
    }

    private func performSignOut() {
        #if canImport(FirebaseAuth)
        do { try Auth.auth().signOut() } catch { print("SignOut error: \(error)") }
        #endif
        cachedDisplayName = nil
        cachedEmail = nil
        tableView.reloadData()

        let login = LoginViewController()
        login.modalPresentationStyle = .fullScreen
        DispatchQueue.main.async {
            self.present(login, animated: true)
        }
    }

    func presentAccountDeleteConfirm() {
        let ac = UIAlertController(
            title: "Hesabı Sil",
            message: "Bu işlem geri alınamaz. Devam etmek istiyor musun?",
            preferredStyle: .alert
        )
        ac.addAction(UIAlertAction(title: "İptal", style: .cancel))
        ac.addAction(UIAlertAction(title: "Sil", style: .destructive, handler: { [weak self] _ in
            self?.performAccountDeletion()
        }))
        present(ac, animated: true)
    }

    func performAccountDeletion() {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            showSimpleAlert(title: "Hesabı Sil", message: "Giriş yapılmadı.")
            return
        }

        user.delete { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error as NSError? {
                    self.showSimpleAlert(
                        title: "Hesabı Sil",
                        message: "Hesap silinemedi: \(error.localizedDescription)\n\nGüvenlik nedeniyle tekrar giriş yapıp yeniden dene."
                    )
                    return
                }

                self.cachedDisplayName = nil
                self.cachedEmail = nil
                self.tableView.reloadData()

                let login = LoginViewController()
                login.modalPresentationStyle = .fullScreen
                self.present(login, animated: true)
            }
        }
        #else
        showSimpleAlert(title: "Hesabı Sil", message: "FirebaseAuth bağlı değil.")
        #endif
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
    // Taskly-like daily reminder toggle (08:00)
    private let dailyReminderKey = "trackly.dailyReminder.enabled"

    private func enableDailyReminder() {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.scheduleDailyMotivationNotification()

                case .notDetermined:
                    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self.showSimpleAlert(title: "Bildirimler", message: error.localizedDescription)
                                UserDefaults.standard.set(false, forKey: self.dailyReminderKey)
                                self.tableView.reloadData()
                                return
                            }
                            if granted {
                                self.scheduleDailyMotivationNotification()
                            } else {
                                UserDefaults.standard.set(false, forKey: self.dailyReminderKey)
                                self.tableView.reloadData()
                            }
                        }
                    }

                case .denied:
                    // izin kapalıysa toggle'ı kapat ve kullanıcıyı bilgilendir
                    UserDefaults.standard.set(false, forKey: self.dailyReminderKey)
                    self.tableView.reloadData()
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

    private func cancelDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailyMotivationIdentifier])
    }

    private func requestDailyMotivationNotification() {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
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
                    // Sessizce kur (Taskly gibi): kullanıcıya ek alert göstermeyelim
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
// MARK: - Brand Color (Trackly)
private extension UIColor {
    static var tracklyBlue: UIColor {
        UIColor(red: 0/255, green: 107/255, blue: 255/255, alpha: 1.0)
    }
}

// MARK: - ProfilePanelViewController (Taskly tarzı sheet)
import UIKit

final class ProfilePanelViewController: UITableViewController {
    var displayName: String?
    var email: String?
    weak var host: SettingsViewController?

    private enum Row: Int, CaseIterable { case name = 0, mail, signOut, delete }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = .systemGroupedBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 64
        tableView.estimatedRowHeight = 64
        title = "Hesap"
        // Make swipe gestures move the sheet (Taskly-like) instead of scrolling content
        tableView.isScrollEnabled = true
        tableView.alwaysBounceVertical = true
        tableView.bounces = true
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let symbolCfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)

        switch Row(rawValue: indexPath.row)! {
        case .name:
            var cfg = UIListContentConfiguration.valueCell()
            cfg.text = "Kullanıcı Adı"
            cfg.secondaryText = displayName ?? "—"
            cfg.textProperties.adjustsFontForContentSizeCategory = true
            cfg.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            cfg.textProperties.font = .preferredFont(forTextStyle: .body)
            cfg.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
            cfg.secondaryTextProperties.color = .secondaryLabel
            cfg.prefersSideBySideTextAndSecondaryText = true
            cfg.image = UIImage(systemName: "person.circle")
            cfg.imageProperties.preferredSymbolConfiguration = symbolCfg
            cfg.imageProperties.maximumSize = CGSize(width: 30, height: 30)
            cfg.imageToTextPadding = 12
            cell.contentConfiguration = cfg
            cell.selectionStyle = .none
            cell.accessoryType = .none

        case .mail:
            var cfg = UIListContentConfiguration.valueCell()
            cfg.text = "E-posta"
            cfg.secondaryText = email ?? "—"
            cfg.textProperties.adjustsFontForContentSizeCategory = true
            cfg.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            cfg.textProperties.font = .preferredFont(forTextStyle: .body)
            cfg.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
            cfg.secondaryTextProperties.color = .secondaryLabel
            cfg.prefersSideBySideTextAndSecondaryText = true
            cfg.image = UIImage(systemName: "envelope")
            cfg.imageProperties.preferredSymbolConfiguration = symbolCfg
            cfg.imageProperties.maximumSize = CGSize(width: 30, height: 30)
            cfg.imageToTextPadding = 12
            cell.contentConfiguration = cfg
            cell.selectionStyle = .none
            cell.accessoryType = .none

        case .signOut:
            var cfg = UIListContentConfiguration.cell()
            cfg.text = "Çıkış Yap"
            cfg.textProperties.font = .preferredFont(forTextStyle: .footnote)
            cfg.image = UIImage(systemName: "rectangle.portrait.and.arrow.right")
            cfg.imageProperties.preferredSymbolConfiguration = symbolCfg
            cfg.imageProperties.maximumSize = CGSize(width: 30, height: 30)
            cfg.imageToTextPadding = 12
            cell.contentConfiguration = cfg
            cell.accessoryType = .none

        case .delete:
            var cfg = UIListContentConfiguration.cell()
            cfg.text = "Hesabı Sil"
            cfg.textProperties.font = .preferredFont(forTextStyle: .footnote)
            cfg.textProperties.color = .systemRed
            cfg.image = UIImage(systemName: "trash")
            cfg.imageProperties.preferredSymbolConfiguration = symbolCfg
            cfg.imageProperties.maximumSize = CGSize(width: 30, height: 30)
            cfg.imageToTextPadding = 12
            cell.contentConfiguration = cfg
            cell.accessoryType = .none
        }

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .secondarySystemGroupedBackground
        cell.backgroundConfiguration = bg
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = true
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let parent = host ?? (presentingViewController as? SettingsViewController) else { return }
        switch Row(rawValue: indexPath.row)! {
        case .name, .mail:
            break
        case .signOut:
            dismiss(animated: true) {
                parent.presentSignOutConfirm()
            }
        case .delete:
            dismiss(animated: true) {
                parent.presentAccountDeleteConfirm()
            }
        }
    }
}

import SwiftUI
#Preview {
    ViewControllerPreview {
        SettingsViewController()
    }
}
