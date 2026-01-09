//
//  VideoSplashViewController.swift
//  Stride
//
//  Created by EfeBülbül on 7.01.2026.
//

import UIKit
import AVFoundation

final class VideoSplashViewController: UIViewController {

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerItem: AVPlayerItem?

    private var itemStatusObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isOpaque = true
        view.backgroundColor = .black
        setupVideo()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("👀 VideoSplashViewController appeared. bounds:", view.bounds)
        player?.play()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }

    deinit {
        itemStatusObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func setupVideo() {
        // Koşan adam videosu burada aranır. Dosya adın farklıysa sadece bu ismi değiştir.
        let resourceName = "splash" // örn: "runner"
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") else {
            print("❌ \(resourceName).mp4 bulunamadı")
            return
        }
        print("🎬 Splash video found:", url.lastPathComponent)
        print("📐 view.bounds at setupVideo:", view.bounds)

        let item = AVPlayerItem(url: url)
        self.playerItem = item

        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false
        player.play() // Attempt to start immediately; if not ready yet, KVO below will start again.

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)

        self.player = player
        self.playerLayer = layer

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loopVideo),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        // 1) Start playback when the item is ready.
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            print("📺 AVPlayerItem status:", item.status.rawValue, "error:", item.error?.localizedDescription ?? "nil")

            switch item.status {
            case .readyToPlay:
                DispatchQueue.main.async {
                    self.player?.play()
                }
            case .failed:
                print("❌ AVPlayerItem failed:", item.error as Any)
            default:
                break
            }
        }
    }

    @objc private func loopVideo() {
        guard let player else { return }
        player.seek(to: .zero)
        player.play()
    }
}
