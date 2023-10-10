//
//  QueuePlayer.swift
//  CapacitorNativeAudioStreamer
//
//  Created by Олег  Руссу on 09/10/2023.
//

import Foundation


class QueuePlayer: NSObject {

    private weak var owner: NativeAudio!
    weak var queueController: QueueController!
    let trailingTimeSeconds: Double
    private let timerUpdateInterval: Double
    private let useFade: Bool

    private var playing: AudioAsset? = nil
    private var trailing: AudioAsset? = nil
    private var timer: Timer2? = nil
    private var duration: Double = 0.0
    private var currentTime: Double = 0.0
    private var volume: Float = 1.0
    private var unloaded = false

    init(owner: NativeAudio, queueController: QueueController, trailingTimeSeconds: Double, timerUpdateInterval: Double, useFade: Bool) {
        self.owner = owner
        self.queueController = queueController
        self.trailingTimeSeconds = trailingTimeSeconds
        self.timerUpdateInterval = timerUpdateInterval
        self.useFade = useFade
    }

    func playTrack(track: QueueTrack, time: Double = 0.0) {
        unload()
        unloaded = false
        startPlay(track: track, time: time)
        notifyPlaying()
    }

    private func startPlay(track: QueueTrack, time: Double = 0.0) {
        playing = AudioAsset(
            owner: owner,
            queueTrack: track,
            queuePlayer: self,
            withAssetId: track.assetId,
            withPath: track.url,
            withChannels: 1,
            withVolume: self.volume as NSNumber,
            useFade: self.useFade
        )
        duration = playing?.getDuration() ?? 0.0
        playing!.play(time: time)
        currentTime = 0.0
        scheduleTimer()


    }

    func pause() {
        timer?.invalidate()
        trailing?.unload()
        playing?.pause()
        notifyPause()
    }

    func resume() {
        playing?.resume()
        scheduleTimer()
    }

    func getCurrentTime() -> Double {
        return playing?.getCurrentTime() ?? 0.0
    }

    func getPlayingTrackId() -> String? {
        return playing?.queueTrack.id
    }

    func isPlaying() -> Bool {
        return playing?.isPlaying() == true
    }

    func isPaused() -> Bool {
        return playing?.isPaused == true
    }

    func seek(time: Double) {
        if (!isPaused() && !isPlaying()) {
            return
        }
        playing!.seekTo(time: time)
        currentTime = time
        toNextOrNotify()
    }

    func isTrailingAssetId(assetId: String) -> Bool {
        playing?.assetId == assetId
    }

    func isPlayingAssetId(assetId: String) -> Bool {
        return playing?.assetId == assetId
    }

    func setVolume(volume: Float) {
        self.volume = volume
        self.playing?.setVolume(volume: self.volume as NSNumber)
        self.trailing?.setVolume(volume: self.volume as NSNumber)
    }

    func unload() {
        timer?.invalidate()
        timer = nil
        playing?.unload()
        trailing?.unload()
        playing = nil
        trailing = nil
        unloaded = true
    }

    func unload(assetId: String) {
        if (trailing?.assetId == assetId) {
            trailing?.unload()
            return
        }
        if (playing?.assetId == assetId) {
            playing?.unload()
        }
    }

    private func scheduleTimer() {
        let updateInterval = timerUpdateInterval


        timer = Timer2(interval: updateInterval, function: { [weak self] in
            self?.advanceTimer()
        })
        timer!.start()
    }

    private func advanceTimer() {
        if (playing == nil) {
            return
        }
        duration = playing!.getDuration()
        if (currentTime < duration) {
            currentTime = (playing?.getCurrentTime() ?? 0.0)
            toNextOrNotify()
        }
    }

    private func toNextOrNotify() {
        if (trailingTimeSeconds == 0.0) {
            notifyPlaying()
            return
        }
        if (duration - currentTime <= trailingTimeSeconds) {
            tryMoveToNext()
            return
        }
        if (playing?.isPlaying() == false) {
            return
        }
        notifyPlaying()
    }

    private func notifyPlaying() {
        if (unloaded) {
            return
        }
        if (playing == nil) {
            return
        }

        guard let id = playing?.queueTrack.id else { return }

        var data: [String: Any] = [:]
        data["time"] = self.currentTime
        data["duration"] = self.duration
        data["id"] = self.queueController.id
        data["trackId"] = id
        data["index"] = queueController.index
        owner.notifyListeners(QueueController.kEventPlaying, data: data)
    }

    private func notifyPause() {
        if (unloaded) {
            return
        }
        guard let id = playing?.queueTrack.id else { return }

        var data: [String: Any] = [:]
        data["time"] = self.currentTime
        data["duration"] = self.duration
        data["id"] = self.queueController.id
        data["trackId"] = id
        data["index"] = queueController.index
        owner.notifyListeners(QueueController.kEventTrackPause, data: data)
    }

    private func tryMoveToNext() {
        guard let nextTrack = queueController.requestNextTrack() else {
            notifyPlaying()
            return
        }

        trailing?.unload()
        trailing = playing
        timer?.invalidate()
        startPlay(track: nextTrack, time: 0.0)
    }
}
