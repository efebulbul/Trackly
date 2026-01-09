//
//  GroupsViewController.swift
//  Stride
//
//  Created by EfeBülbül on 9.01.2026.
//

import UIKit

/// Tab Bar'daki "Groups" sekmesi.
/// Üstte iki taraflı bir toggle var:
/// - Sol: "You" (HealthKit / günlük veriler)
/// - Sağ: "Groups" (Firebase / grup & sohbet)
final class GroupsViewController: UIViewController {

    // MARK: - UI
    private let topBar = UIView()
    private let buttonsStack = UIStackView()
    private let youButton = UIButton(type: .system)
    private let groupsButton = UIButton(type: .system)
    private let indicator = UIView()
    private let containerView = UIView()

    // MARK: - State
    private enum Tab {
        case you
        case groups
    }

    private var selectedTab: Tab = .you

    private var indicatorLeadingConstraint: NSLayoutConstraint?

    // Child VCs (şimdilik placeholder; sonra gerçek ekranları buraya bağlayacağız)
    private let youVC = YouDailyViewController()
    private let groupsVC = GroupsChatListViewController()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        navigationItem.title = "Groups"
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false

        setupTopToggle()
        setupContainer()

        // Default: You
        switchTo(.you, animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Buton genişlikleri layout sonrası kesinleşir; indicator'ı doğru yerde tut.
        updateIndicatorPosition(animated: false)
    }

    // MARK: - Setup
    private func setupTopToggle() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        buttonsStack.axis = .horizontal
        buttonsStack.distribution = .fillEqually
        buttonsStack.alignment = .fill
        buttonsStack.spacing = 0
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(buttonsStack)

        configureTopButton(youButton, title: "You")
        configureTopButton(groupsButton, title: "Groups")

        youButton.addTarget(self, action: #selector(didTapYou), for: .touchUpInside)
        groupsButton.addTarget(self, action: #selector(didTapGroups), for: .touchUpInside)

        buttonsStack.addArrangedSubview(youButton)
        buttonsStack.addArrangedSubview(groupsButton)

        indicator.backgroundColor = .label
        indicator.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(indicator)

        // Layout
        let topGuide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: topGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Buttons
            buttonsStack.topAnchor.constraint(equalTo: topBar.topAnchor),
            buttonsStack.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            buttonsStack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            buttonsStack.heightAnchor.constraint(equalToConstant: 44),

            // Indicator
            indicator.topAnchor.constraint(equalTo: buttonsStack.bottomAnchor),
            indicator.heightAnchor.constraint(equalToConstant: 2),
            indicator.bottomAnchor.constraint(equalTo: topBar.bottomAnchor)
        ])

        // Indicator: genişlik = 1 buton
        let width = indicator.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5)
        width.isActive = true

        let leading = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        leading.isActive = true
        indicatorLeadingConstraint = leading

        // İnce alt çizgi (opsiyonel ama güzel durur)
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
    }

    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureTopButton(_ button: UIButton, title: String) {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        button.configuration = config
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
    }

    // MARK: - Actions
    @objc private func didTapYou() {
        switchTo(.you, animated: true)
    }

    @objc private func didTapGroups() {
        switchTo(.groups, animated: true)
    }

    // MARK: - Switching
    private func switchTo(_ tab: Tab, animated: Bool) {
        guard selectedTab != tab else { return }
        selectedTab = tab

        // Button states
        applySelectedStyle()

        // Swap child VC
        let newVC: UIViewController = (tab == .you) ? youVC : groupsVC
        let oldVC: UIViewController? = children.first

        if let oldVC {
            oldVC.willMove(toParent: nil)
            if animated {
                UIView.transition(with: containerView, duration: 0.18, options: [.transitionCrossDissolve, .beginFromCurrentState]) {
                    oldVC.view.removeFromSuperview()
                } completion: { _ in
                    oldVC.removeFromParent()
                }
            } else {
                oldVC.view.removeFromSuperview()
                oldVC.removeFromParent()
            }
        }

        addChild(newVC)
        newVC.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(newVC.view)
        NSLayoutConstraint.activate([
            newVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            newVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            newVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            newVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        newVC.didMove(toParent: self)

        updateIndicatorPosition(animated: animated)
    }

    private func applySelectedStyle() {
        // Basit bir seçili/seçili değil efekti
        let youSelected = (selectedTab == .you)

        youButton.alpha = youSelected ? 1.0 : 0.6
        groupsButton.alpha = youSelected ? 0.6 : 1.0
    }

    private func updateIndicatorPosition(animated: Bool) {
        guard let leading = indicatorLeadingConstraint else { return }
        leading.constant = (selectedTab == .you) ? 0 : (view.bounds.width * 0.5)

        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                self.view.layoutIfNeeded()
            }
        } else {
            view.layoutIfNeeded()
        }
    }
}

// MARK: - Placeholders (sonra gerçek ekranlara bağlayacağız)

/// Sol sekme: HealthKit günlük veri ekranı (placeholder)
final class YouDailyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "You • Günlük veriler (HealthKit)"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

/// Sağ sekme: Grup/sohbet listesi (Firebase) (placeholder)
final class GroupsChatListViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "Groups • Sohbetler (Firebase)"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
