//
//  SettingsViewController
//  Stride
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit
import UserNotifications
import SafariServices
import MessageUI
import StoreKit
import AuthenticationServices
import CryptoKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif


final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, MFMailComposeViewControllerDelegate, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private enum Section: Int, CaseIterable {
        case profile
        case preferences
        case supportInfo
    }

    private enum PreferencesRow: Int, CaseIterable {
        case language
        case theme
        case notifications
        case units
    }

    private enum SupportInfoRow: Int, CaseIterable {
        case rateUs
        case support
        case legal
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // MARK: - Apple reauth (for account deletion)
    private var appleReauthNonce: String?
    private var pendingAppleDeletion: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Ayarlar"
        view.backgroundColor = .systemBackground

        // TableView setup
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "profileCell")

        view.addSubview(tableView)

        // Taskly-like spacing
        tableView.backgroundColor = .systemGroupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 6
        }

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
        case .preferences:
            return PreferencesRow.allCases.count
        case .supportInfo:
            return SupportInfoRow.allCases.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sec = Section(rawValue: section) else { return nil }
        switch sec {
        case .profile:
            return nil
        case .preferences:
            return "GENEL TERCİHLER"
        case .supportInfo:
            return "DESTEK VE BİLGİ"
        }
    }

    // MARK: - Section spacing (reduce gaps)
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sec = Section(rawValue: section) else { return UITableView.automaticDimension }
        switch sec {
        case .profile:
            return .leastNormalMagnitude
        case .preferences, .supportInfo:
            return 26
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let sec = Section(rawValue: section) else { return nil }
        switch sec {
        case .profile, .preferences:
            return UIView(frame: .zero)
        case .supportInfo:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard let sec = Section(rawValue: section) else { return UITableView.automaticDimension }
        switch sec {
        case .profile:
            return 14
        case .preferences:
            return 12
        case .supportInfo:
            return UITableView.automaticDimension
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

        case .preferences:
            guard let row = PreferencesRow(rawValue: indexPath.row) else { return cell }

            // default cell behaviour (override per-row)
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

            switch row {
            case .notifications:
                config.text = "Bildirimler"
                config.image = UIImage(systemName: "bell.badge.fill")
                config.imageProperties.tintColor = .strideBlue
                config.secondaryText = "Durum kontrol ediliyor..."
                config.secondaryTextProperties.color = .secondaryLabel

                // Mevcut izin durumuna göre alt metni güncelle
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        guard let visibleCell = tableView.cellForRow(at: indexPath) else { return }
                        var cfg = visibleCell.defaultContentConfiguration()
                        cfg.text = "Bildirimler"
                        cfg.image = UIImage(systemName: "bell.badge")
                        cfg.imageProperties.preferredSymbolConfiguration =
                            UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
                        cfg.imageProperties.tintColor = .strideBlue

                        switch settings.authorizationStatus {
                        case .authorized, .provisional:
                            cfg.secondaryText = "Bildirimler aktif"
                            cfg.secondaryTextProperties.color = .systemGreen
                        case .denied:
                            cfg.secondaryText = "Bildirimler kapalı"
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
                config.imageProperties.tintColor = .strideBlue
                config.secondaryTextProperties.color = .secondaryLabel

            case .theme:
                config.text = "Tema"
                config.secondaryText = currentThemeTitle()
                config.image = UIImage(systemName: "paintpalette")
                config.imageProperties.tintColor = .strideBlue
                config.secondaryTextProperties.color = .secondaryLabel

            case .units:
                config.text = "Ölçü Birimi"
                config.secondaryText = currentDistanceUnitTitle()
                config.image = UIImage(systemName: "ruler")
                config.imageProperties.tintColor = .strideBlue
                config.secondaryTextProperties.color = .secondaryLabel
            }

            config.imageProperties.preferredSymbolConfiguration =
                UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)

        case .supportInfo:
            guard let row = SupportInfoRow(rawValue: indexPath.row) else { return cell }

            // default cell behaviour (override per-row)
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

            switch row {
            case .rateUs:
                config.text = "Bizi Değerlendirin"
                config.secondaryText = "App Store’da puan ver"
                config.image = UIImage(systemName: "star.bubble")
                config.imageProperties.tintColor = .strideBlue
                config.secondaryTextProperties.color = .secondaryLabel

            case .support:
                config.text = "Destek & Geri Bildirim"
                config.image = UIImage(systemName: "envelope")
                config.imageProperties.tintColor = .strideBlue

            case .legal:
                config.text = "Gizlilik & Şartlar"
                config.image = UIImage(systemName: "hand.raised")
                config.imageProperties.tintColor = .strideBlue
            }

            config.imageProperties.preferredSymbolConfiguration =
                UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        }

        cell.contentConfiguration = config
        // Taskly-like rounded card cell background for all non-profile cells
        var bgSet: UIBackgroundConfiguration
        if #available(iOS 18.0, *) {
            bgSet = UIBackgroundConfiguration.listCell()
        } else {
            bgSet = UIBackgroundConfiguration.listGroupedCell()
        }
        bgSet.backgroundColor = .secondarySystemGroupedBackground
        cell.backgroundConfiguration = bgSet
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

        case .preferences:
            guard let row = PreferencesRow(rawValue: indexPath.row) else { return }
            switch row {
            case .notifications:
                openAppSettings()
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
            case .units:
                presentDistanceUnitPicker()
            }

        case .supportInfo:
            guard let row = SupportInfoRow(rawValue: indexPath.row) else { return }
            switch row {
            case .rateUs:
                requestAppReview()
            case .support:
                presentSupportFeedback()
            case .legal:
                presentLegalLinks()
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
            cfg.imageProperties.tintColor = .strideBlue
            cell.accessoryView = nil
        } else {
            cfg.text = "Giriş Yap"
            cfg.secondaryText = "Hesabınla giriş yap"
            cfg.image = UIImage(systemName: "person.crop.circle")
            cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            cfg.imageProperties.tintColor = .strideBlue
            cell.accessoryView = nil
        }
        #else
        cfg.text = "Giriş Yap"
        cfg.secondaryText = "Hesabınla giriş yap"
        cfg.image = UIImage(systemName: "person.crop.circle")
        cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        cfg.imageProperties.tintColor = .strideBlue
        #endif

        cfg.textProperties.font = .preferredFont(forTextStyle: .headline)
        cfg.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = cfg

        // Taskly-like rounded card cell background for profile row
        var bg: UIBackgroundConfiguration
        if #available(iOS 18.0, *) {
            bg = UIBackgroundConfiguration.listCell()
        } else {
            bg = UIBackgroundConfiguration.listGroupedCell()
        }
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

        // If signed in with Apple, we must reauthenticate before deletion when required.
        if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            pendingAppleDeletion = true
            startAppleReauth()
            return
        }

        // For other providers, try delete directly; if Firebase demands recent login, ask user to sign out/in again.
        user.delete { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error as NSError? {
                    // Most common case: requires-recent-login
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

    // MARK: - Apple reauthentication (Firebase) for deletion

    private func startAppleReauth() {
        let nonce = randomNonceString()
        appleReauthNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [] // we only need an id token
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard pendingAppleDeletion else { return }

        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        guard let tokenData = appleIDCredential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            showSimpleAlert(title: "Hesabı Sil", message: "Apple kimlik doğrulama token'ı alınamadı.")
            pendingAppleDeletion = false
            return
        }
        guard let nonce = appleReauthNonce else {
            showSimpleAlert(title: "Hesabı Sil", message: "Güvenlik doğrulaması tamamlanamadı. Tekrar dene.")
            pendingAppleDeletion = false
            return
        }

        let credential = OAuthProvider.appleCredential(withIDToken: tokenString,
                                                      rawNonce: nonce,
                                                      fullName: appleIDCredential.fullName)

        user.reauthenticate(with: credential) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error as NSError? {
                    self.pendingAppleDeletion = false
                    self.showSimpleAlert(
                        title: "Hesabı Sil",
                        message: "Doğrulama başarısız: \(error.localizedDescription)"
                    )
                    return
                }

                user.delete { [weak self] error in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.pendingAppleDeletion = false

                        if let error = error as NSError? {
                            self.showSimpleAlert(
                                title: "Hesabı Sil",
                                message: "Hesap silinemedi: \(error.localizedDescription)"
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
            }
        }
        #else
        pendingAppleDeletion = false
        #endif
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if pendingAppleDeletion {
            pendingAppleDeletion = false
            showSimpleAlert(title: "Hesabı Sil", message: "Apple doğrulaması iptal edildi veya başarısız oldu.")
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    // MARK: - Nonce helpers (Apple Sign-In)

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess { return 0 }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Ölçü Birimi

    private func currentDistanceUnitTitle() -> String {
        switch UserDefaults.standard.strideDistanceUnit {
        case .kilometers: return "Kilometre (km)"
        case .miles: return "Mil (mi)"
        }
    }

    private func presentDistanceUnitPicker() {
        let ac = UIAlertController(title: "Ölçü Birimi", message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: "Kilometre (km)", style: .default, handler: { _ in
            self.setDistanceUnit(.kilometers)
        }))

        ac.addAction(UIAlertAction(title: "Mil (mi)", style: .default, handler: { _ in
            self.setDistanceUnit(.miles)
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

    private func setDistanceUnit(_ unit: StrideDistanceUnit) {
        UserDefaults.standard.strideDistanceUnit = unit
        NotificationCenter.default.post(name: .strideDistanceUnitDidChange, object: nil)
        tableView.reloadData()
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


    // MARK: - Table Footer (Version)
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sec = Section(rawValue: section) else { return nil }
        guard sec == .supportInfo else { return nil }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "Version \(version)"
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footer = view as? UITableViewHeaderFooterView else { return }
        footer.textLabel?.textAlignment = .center
        footer.textLabel?.textColor = .secondaryLabel
    }

    private func requestAppReview() {
        guard let scene = view.window?.windowScene else {
            // If we can't access a scene (rare), just do nothing safely.
            // The in-app review prompt is rate-limited by Apple anyway.
            return
        }

        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            showSimpleAlert(title: "Ayarlar", message: "Ayarlar açılamadı.")
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func showSimpleAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(ac, animated: true)
    }

    // MARK: - Support & Feedback

    private var supportEmailAddress: String { "info@efebulbul.com" }
    private var supportEmailSubject: String { "stride Destek / Geri Bildirim" }

    private func presentSupportFeedback() {
        let ac = UIAlertController(title: "Destek & Geri Bildirim", message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: "E-posta Gönder", style: .default, handler: { [weak self] _ in
            self?.presentSupportMailComposer()
        }))

        ac.addAction(UIAlertAction(title: "Hata Bildir", style: .default, handler: { [weak self] _ in
            self?.presentSupportMailComposer(isBugReport: true)
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

    private func presentSupportMailComposer(isBugReport: Bool = false) {
        let subject = isBugReport ? "stride Hata Bildirimi" : supportEmailSubject
        let body = buildSupportMailBody(isBugReport: isBugReport)

        if MFMailComposeViewController.canSendMail() {
            let vc = MFMailComposeViewController()
            vc.setToRecipients([supportEmailAddress])
            vc.setSubject(subject)
            vc.setMessageBody(body, isHTML: false)
            vc.mailComposeDelegate = self
            present(vc, animated: true)
            return
        }

        // Fallback: mailto
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        let mailto = "mailto:\(supportEmailAddress)?subject=\(encodedSubject)&body=\(encodedBody)"
        guard let url = URL(string: mailto), UIApplication.shared.canOpenURL(url) else {
            showSimpleAlert(title: "E-posta", message: "E-posta uygulaması açılamadı.")
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func buildSupportMailBody(isBugReport: Bool) -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        let device = UIDevice.current.model
        let os = UIDevice.current.systemVersion

        var lines: [String] = []
        lines.append("Merhaba,")
        lines.append("")
        lines.append(isBugReport ? "Bir hata bildirmek istiyorum:" : "Geri bildirimim:")
        lines.append("")
        lines.append("—")
        lines.append("Uygulama: stride")
        lines.append("Versiyon: \(appVersion) (\(buildNumber))")
        lines.append("Cihaz: \(device)")
        lines.append("iOS: \(os)")
        lines.append("—")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - MFMailComposeViewControllerDelegate

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true)
    }

    // MARK: - Legal

    private var privacyPolicyURLString: String { "https://www.efebulbul.com" }
    private var termsOfUseURLString: String { "https://www.efebulbul.com" }

    private func presentLegalLinks() {
        let ac = UIAlertController(title: "Gizlilik & Şartlar", message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: "Gizlilik Politikası", style: .default, handler: { [weak self] _ in
            self?.openInSafariView(self?.privacyPolicyURLString)
        }))
        ac.addAction(UIAlertAction(title: "Kullanım Şartları", style: .default, handler: { [weak self] _ in
            self?.openInSafariView(self?.termsOfUseURLString)
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

    private func openInSafariView(_ urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            showSimpleAlert(title: "Bağlantı", message: "Bağlantı açılamadı.")
            return
        }
        let vc = SFSafariViewController(url: url)
        present(vc, animated: true)
    }

}
// MARK: - Brand Color (stride)
private extension UIColor {
    static var strideBlue: UIColor {
        UIColor(red: 0/255, green: 107/255, blue: 255/255, alpha: 1.0)
    }
}

// MARK: - Distance Unit (App-wide)

enum StrideDistanceUnit: String {
    case kilometers
    case miles
}

private extension UserDefaults {
    static let strideDistanceUnitKey = "stride.distanceUnit"

    var strideDistanceUnit: StrideDistanceUnit {
        get {
            let raw = string(forKey: Self.strideDistanceUnitKey)
            return StrideDistanceUnit(rawValue: raw ?? "") ?? .kilometers
        }
        set {
            set(newValue.rawValue, forKey: Self.strideDistanceUnitKey)
        }
    }
}

extension Notification.Name {
    static let strideDistanceUnitDidChange = Notification.Name("stride.distanceUnitDidChange")
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
