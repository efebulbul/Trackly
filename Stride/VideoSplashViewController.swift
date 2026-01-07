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

    private let posterImageView = UIImageView()
    private var itemStatusObservation: NSKeyValueObservation?
    private var layerReadyObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isOpaque = true
        view.backgroundColor = .black
        setupPoster()
        setupVideo()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
        posterImageView.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Playback is started when the AVPlayerItem becomes readyToPlay.
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }

    deinit {
        itemStatusObservation?.invalidate()
        layerReadyObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func setupVideo() {
        // Koşan adam videosu burada aranır. Dosya adın farklıysa sadece bu ismi değiştir.
        let resourceName = "splash" // örn: "runner"
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") else {
            print("❌ \(resourceName).mp4 bulunamadı")
            return
        }

        let item = AVPlayerItem(url: url)
        self.playerItem = item

        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)

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
            guard item.status == .readyToPlay else { return }
            DispatchQueue.main.async {
                self.player?.play()
            }
        }

        // 2) Fade out the poster only when the layer is actually ready to display frames.
        layerReadyObservation = layer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            guard let self else { return }
            guard layer.isReadyForDisplay else { return }
            DispatchQueue.main.async {
                self.hidePosterIfNeeded(animated: true)
                self.layerReadyObservation?.invalidate()
                self.layerReadyObservation = nil
            }
        }
    }

    @objc private func loopVideo() {
        guard let player else { return }
        player.seek(to: .zero)
        player.play()
    }

    private func setupPoster() {
        posterImageView.frame = view.bounds
        posterImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        posterImageView.contentMode = .scaleAspectFill
        posterImageView.backgroundColor = .black
        posterImageView.isOpaque = true

        // ✅ Anında görünen poster: Assets'e "SplashPoster" eklediğinde siyah flash tamamen gider.
        // (Bu poster, LaunchScreen ile aynı görünmeli.)
        posterImageView.image = UIImage(named: "SplashPoster")

        posterImageView.alpha = 1
        view.addSubview(posterImageView)
    }

    private func hidePosterIfNeeded(animated: Bool) {
        guard posterImageView.superview != nil else { return }
        let animations = { self.posterImageView.alpha = 0 }
        let completion: (Bool) -> Void = { _ in self.posterImageView.removeFromSuperview() }

        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }
}
