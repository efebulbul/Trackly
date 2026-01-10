

//
//  GroupsViewController.swift
//  Stride
//
//  Created by EfeBülbül on 9.01.2026.
//

import UIKit

/// Tab Bar'daki "Groups" sekmesi.
/// Sade ekran: sadece başlık + ortada placeholder metin.
final class GroupsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureTabBarAppearanceIfNeeded()

        navigationItem.title = "Groups"
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureTabBarAppearanceIfNeeded()
    }

    private func configureTabBarAppearanceIfNeeded() {
        guard let tabBar = tabBarController?.tabBar else { return }

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}
