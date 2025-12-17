//
//  SceneDelegate.swift
//  Trackly
//
//  Created by EfeBülbül on 5.11.2025.
//

import UIKit
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // Tema
        window.overrideUserInterfaceStyle = resolvedInterfaceStyle()

        // İlk açılışta: giriş yoksa direkt Login root olsun (Run ekranı hiç görünmesin)
        let isLoggedIn: Bool
        #if canImport(FirebaseAuth)
        isLoggedIn = (Auth.auth().currentUser != nil)
        #else
        isLoggedIn = (UserSession.shared.currentUser != nil)
        #endif

        if isLoggedIn {
            setRoot(makeMainRoot(), animated: false)
            // İstersen burada direkt Run tab'ını seçtiriyoruz
            switchToMainAndShowRun(animated: false)
        } else {
            setRoot(makeLoginRoot(), animated: false)
        }

        window.makeKeyAndVisible()

        // Login başarıyla olunca (LoginVC içinde post edilecek) main'e geç
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidLogin),
            name: Notification.Name("Trackly.didLogin"),
            object: nil
        )

        // (Opsiyonel) Logout olunca tekrar login'e dönmek istersen
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidLogout),
            name: Notification.Name("Trackly.didLogout"),
            object: nil
        )
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        presentLoginIfNeeded(animated: true)
    }

    // MARK: - Login
    private func presentLoginIfNeeded(animated: Bool) {
        let notLoggedIn: Bool

        #if canImport(FirebaseAuth)
        notLoggedIn = (Auth.auth().currentUser == nil)
        #else
        notLoggedIn = (UserSession.shared.currentUser == nil)
        #endif

        guard notLoggedIn else { return }

        // Root zaten login ise ekstra bir şey yapma
        if window?.rootViewController is LoginViewController { return }

        // Root main ise üstüne login'i full screen bas
        guard let root = window?.rootViewController else { return }
        if root.presentedViewController is LoginViewController { return }

        let login = LoginViewController()
        login.modalPresentationStyle = .fullScreen
        root.present(login, animated: animated)
    }

    private func makeMainRoot() -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let root = storyboard.instantiateInitialViewController() else {
            fatalError("❌ Initial View Controller bulunamadı (TabBar olmalı)")
        }
        return root
    }

    private func makeLoginRoot() -> UIViewController {
        // Login ekranın zaten kendi içinde kapatıp/notify edip akışı sürdürüyor.
        // Root olarak set edince ilk kullanıcıda Run hiç görünmez.
        return LoginViewController()
    }

    private func setRoot(_ vc: UIViewController, animated: Bool) {
        guard let window = self.window else { return }
        if animated {
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
                window.rootViewController = vc
            })
        } else {
            window.rootViewController = vc
        }
    }

    private func switchToMainAndShowRun(animated: Bool) {
        let main = makeMainRoot()
        setRoot(main, animated: animated)

        // Run ekranının olduğu tab index'ini seç (çoğu projede 0)
        if let tab = main as? UITabBarController {
            tab.selectedIndex = 0
        }
    }

    private func switchToLogin(animated: Bool) {
        setRoot(makeLoginRoot(), animated: animated)
    }

    @objc private func handleDidLogin() {
        switchToMainAndShowRun(animated: true)
    }

    @objc private func handleDidLogout() {
        switchToLogin(animated: true)
    }

    // MARK: - Theme
    private func resolvedInterfaceStyle() -> UIUserInterfaceStyle {
        let raw = UserDefaults.standard.integer(forKey: "theme.option")
        switch raw {
        case 1: return .light
        case 2: return .dark
        default: return .unspecified
        }
    }

    // MARK: - Google Sign In
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        #if canImport(GoogleSignIn)
        guard let url = URLContexts.first?.url else { return }
        GIDSignIn.sharedInstance.handle(url)
        #endif
    }
}
