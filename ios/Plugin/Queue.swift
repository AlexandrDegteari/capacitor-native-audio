//
//  QueuePlayer.swift
//  Capacitor
//
//  Created by Degteari Alexandr on 04/10/23.
//

import Foundation
import Capacitor

struct QueueTrack {
    
    
    public let id: String
    public let url: String
    public let name: String
    public let isMusic: Bool
    public let forcePlay: Bool
    
    public var assetId: String {
        get {
            url
        }
    }
    
    public init(jsObject: JSObject) {
        self.id  = String(jsObject["id"] as? Int ?? 0)
        self.url = jsObject["url"] as? String ?? ""
        self.name = jsObject["name"] as? String ?? ""
        self.isMusic = (jsObject["isMusic"] as? Int ?? 0) == 1
        self.forcePlay = (jsObject["forcePlay"] as? Int ?? 0) == 1
    }
}

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

final class Timer2 {
    
    let interval: Double
    var isRunning = false
    var workItem: DispatchWorkItem!
    
    var function: (() -> ())?
    
    init(interval: Double, function: (() -> ())?) {
        self.interval = interval
        self.function = function
    }
    
    func start() {
        workItem?.cancel()
        workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            function?()
            if isRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
                return
            }
            if workItem.isCancelled {
                return
            }
            workItem?.cancel()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
        isRunning = true
    }
    
    func invalidate() {
        if workItem?.isCancelled == false {
            workItem?.cancel()
        }
        isRunning = false
    }
}


final class QueueController {
    
    static let kEventPlaying = "track-playing"
    static let kEventTrackStop = "track-stop"
    static let kEventAllTracksStop = "all-tracks-stop"
    static let kEventTrackPause = "track-pause"
    
    weak var owner: NativeAudio!
    let id: String
    let useFade: Bool
    
    private var tracks: [QueueTrack] = []
    var index: Int = 0
    private var looping = false
    var player: QueuePlayer? = nil
    private var loopIndex = -1
    
    init(owner: NativeAudio, id: String, useFade: Bool) {
        self.owner = owner
        self.id = id
        self.useFade = useFade
    }
    
    func playQueue(
        jsTracks: [JSObject],
        startIndex: Int,
        startTime: Double,
        trailingTimeSeconds: Double,
        timerUpdateInterval: Double,
        volume: Float,
        loop: Bool
    ) {
        if (startIndex >= jsTracks.count) {
            return
        }
        
        tracks = []
        
        for i in 0 ..< jsTracks.count {
            let jsTrack = jsTracks[i]
            let track = QueueTrack(jsObject: jsTrack)
            tracks.append(track)
        }
        
        self.looping = loop
        self.loopIndex = -1
        
        player?.unload()
        index = startIndex
        
        if tracks.isEmpty {
            return
        }
        
        player = QueuePlayer(
            owner: self.owner, 
            queueController: self,
            trailingTimeSeconds: trailingTimeSeconds,
            timerUpdateInterval: timerUpdateInterval,
            useFade: self.useFade
        )
        
        player!.setVolume(volume: volume)
        let track = tracks[index]
        player!.playTrack(track: track, time: startTime)
    }
    
    
    func updateQueue(jsTracks: [JSObject]) {
        if (jsTracks.isEmpty) {
            notifyStop(assetId: player?.getPlayingTrackId() ?? "")
            unload()
            return
        }
        var newTracks: [QueueTrack] = []
        let currentPlayingTrackId = player?.getPlayingTrackId() ?? ""
        var indexToSet = -1
        for i in 0 ..< jsTracks.count {
            let jsTrack = jsTracks[i]
            let track = QueueTrack(jsObject: jsTrack)
            newTracks.append(track)
            if (track.id != currentPlayingTrackId) {
                continue
            }
            indexToSet = i
        }
        tracks = []
        tracks.append(contentsOf: newTracks)
        
        if (indexToSet >= 0) {
            self.index = indexToSet
            return
        }
        
        if (index >= tracks.count) {
            index = tracks.count - 1
        }
    }
    
    func pause() -> Bool {
        if (player?.isPlaying() != true) {
            return false
        }
        player?.pause()
        return true
    }

    func resume() -> Bool {
        if (player?.isPaused() != true) {
            return false
        }
        player?.resume()
        return true
    }
    
    func isPlaying() -> Bool {
        player?.isPlaying() == true
    }

    func isPaused() -> Bool {
        player?.isPaused() == true
    }
    
    func toNextTrack() -> Bool {
        let nextTrack = requestNextTrackInternal()
        if (nextTrack == nil) {
            return false
        }
        player?.unload()
        player?.playTrack(track: nextTrack!)
        return true
    }
    
    func toPreviousTrack() -> Bool {
        let previousTrack = requestPreviousTrackInternal()
        if (previousTrack == nil) {
            return false
        }
        player?.unload()
        player?.playTrack(track: previousTrack!)
        return true
    }
    
    func seek(time: Double) -> Bool {
        if (player?.isPlaying() != true && player?.isPaused() != true) {
            return false
        }

        player?.seek(time: time)
        return true
    }
    
    func getCurrentTime() -> Double {
        player?.getCurrentTime() ?? 0.0
    }
    
    func setLoopIndex(index: Int, set: Bool) {
        if (loopIndex > tracks.count - 1) {
            return
        }

        loopIndex = set ? index : -1

        if (loopIndex >= 0 && self.index != loopIndex) {
            self.index = loopIndex
            player?.unload()
            player?.playTrack(track : tracks[index])
        }
    }
    
    func setVolume(volume: Float) -> Bool {
        player?.setVolume(volume: volume)
        return player != nil
    }
    
    func queueHasAssetId(assetId: String) -> Bool {
        tracks.first { $0.assetId == assetId } != nil
    }
    
    func requestNextTrack() -> QueueTrack? {
        return requestNextTrackInternal()
    }
    
    private func manageIndexToNext() -> Bool {
        if (loopIndex >= 0) {
            index = loopIndex
            return true
        }
        if (index == tracks.count - 1) {
            if (!maybeRemoveForcePlayTrackOnCurrentIndex(toNext: true)) {
                index = 0
            }
            if (looping) {
                return true
            }
            return false
        }
        if (!maybeRemoveForcePlayTrackOnCurrentIndex(toNext: true)) {
            index += 1
        }
        return true
    }
    
    private func manageIndexToPrevious() -> Bool {
        if (loopIndex >= 0) {
            index = loopIndex
            return true
        }
        if (index == 0) {
            if (looping) {
                _ = maybeRemoveForcePlayTrackOnCurrentIndex(toNext: false)
                index = tracks.count - 1
                return true
            }
            return false
        }
        _ = maybeRemoveForcePlayTrackOnCurrentIndex(toNext: false)
        index -= 1
        return true
    }
    
    private func maybeRemoveForcePlayTrackOnCurrentIndex(toNext: Bool) -> Bool {
        if (tracks.count == 1) {
            return false
        }
        let currentTrack = tracks[index]
        if !currentTrack.forcePlay {
            return false
        }
        
        tracks.remove(at: index)
        if toNext {
            if (index + 1 < tracks.count) {
                index += 1
                return true
            } else {
                if (looping) {
                    index = 0
                    return true
                }
            }
        }
        return false
    }
    
    private func requestNextTrackInternal() -> QueueTrack? {
        if (manageIndexToNext()) {
            if (!tracks.isEmpty) {
                if (index >= tracks.count) {
                    index = tracks.count - 1
                }
            } else {
                return nil
            }
            return tracks[index]
        }
        return nil
    }
    
    private func requestPreviousTrackInternal() -> QueueTrack? {
        if (manageIndexToPrevious()) {
            return tracks[index]
        }
        return nil
    }

    func unload() {
//            queueState = QueueState.IDLE
        player?.unload()
    }
    
    
    func completion(assetId: String) {
        if (tracks.first { $0.assetId == assetId } == nil) {
            return
        }

        if (player!.trailingTimeSeconds == 0.0 && (loopIndex >= 0 || looping)) {
            player!.unload()
            let nextTrack = requestNextTrackInternal()
            if nextTrack != nil {
                player!.playTrack(track: nextTrack!)
            } else {
                notifyStop(assetId: assetId)
            }
            return
        }

        let isPlayingAssetId = player?.isPlayingAssetId(assetId: assetId) == true
        let isTrailingAssetId = player?.isTrailingAssetId(assetId: assetId) == true

        if (isTrailingAssetId && isPlayingAssetId && (loopIndex >= 0 || looping)) {
            player?.unload(assetId: assetId)
            return
        }

        if (isPlayingAssetId) {
            notifyStop(assetId: assetId)
        }
        player?.unload(assetId: assetId)
    }
    
    func error(assetId: String) {
        if (tracks.first { $0.assetId == assetId } == nil) {
            return
        }
        player?.unload()
        notifyStop(assetId: assetId)
    }
    
    func notifyStop(assetId: String) {
        var data: [String: Any] = [:]
        data["id"] = id
        data["trackId"] = assetId
        owner.notifyListeners(QueueController.kEventTrackStop, data: data)
    }

    
}
