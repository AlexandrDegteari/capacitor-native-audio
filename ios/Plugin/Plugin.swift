import AVFoundation
import Foundation
import Capacitor
import CoreAudio


enum MyError: Error {
    case runtimeError(String)
}

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitor.ionicframework.com/docs/plugins/ios
 */
@objc(NativeAudio)
public class NativeAudio: CAPPlugin {

    var audioList: [String : Any] = [:]
    var fadeMusic = false
    var session = AVAudioSession.sharedInstance()

    let nowPlayingContoroller = NowPlayingController()

    private var queueControllers: [String : QueueController] = [:]
    private var sleepTimer: Timer2?

    public override func load() {
        super.load()

        nowPlayingContoroller.stopCallback = { [weak self] in
            self?.stopAllQueues()
        }

        self.fadeMusic = false

        do {
            try self.session.setCategory(AVAudioSession.Category.playback)
            try self.session.setActive(false)
        } catch {
            print("Failed to set session category")
        }
    }

    @objc func configure(_ call: CAPPluginCall) {
        if let fade = call.getBool(Constant.FadeKey) {
            self.fadeMusic = fade
        }
        if let focus = call.getBool(Constant.FocusAudio) {
            do {
                if focus {
                    try self.session.setCategory(AVAudioSession.Category.playback)
                } else {
                    try self.session.setCategory(AVAudioSession.Category.ambient)
                }
            } catch {
                print("Failed to set setCategory audio")
            }
        }
    }

    @objc func preload(_ call: CAPPluginCall) {
        preloadAsset(call, isComplex: true)
    }

    @objc func play(_ call: CAPPluginCall) {
        let audioId = call.getString(Constant.AssetIdKey) ?? ""
        let time = call.getDouble("time") ?? 0
        if audioId != "" {
            let queue = DispatchQueue(label: "com.getcapacitor.community.audio.complex.queue", qos: .userInitiated)

            queue.async {
                if self.audioList.count > 0 {
                    let asset = self.audioList[audioId]

                    if asset != nil {
                        if asset is AudioAsset {
                            let audioAsset = asset as? AudioAsset

                            if self.fadeMusic {
                                audioAsset?.playWithFade(time: time)
                            } else {
                                audioAsset?.play(time: time)
                            }
                            call.resolve()
                        } else if (asset is Int32) {
                            let audioAsset = asset as? NSNumber ?? 0
                            AudioServicesPlaySystemSound(SystemSoundID(audioAsset.intValue ))
                            call.resolve()
                        } else {
                            call.reject(Constant.ErrorAssetNotFound)
                        }
                    }
                }
            }
        }
    }

    @objc private func getAudioAsset(_ call: CAPPluginCall) -> AudioAsset? {
        let audioId = call.getString(Constant.AssetIdKey) ?? ""
        if audioId == "" {
            call.reject(Constant.ErrorAssetId)
            return nil
        }
        if self.audioList.count > 0 {
            let asset = self.audioList[audioId]
            if asset != nil && asset is AudioAsset {
                return asset as? AudioAsset
            }
        }
        call.reject(Constant.ErrorAssetNotFound + " - " + audioId)
        return nil
    }


    @objc func getDuration(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        call.resolve([
            "duration": audioAsset.getDuration()
        ])
    }

    @objc func getList(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        call.resolve([
            "list": audioAsset.getList()
        ])
    }

    @objc func getCurrentTime(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        call.resolve([
            "currentTime": audioAsset.getCurrentTime()
        ])
    }

    @objc func resume(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        audioAsset.resume()
        call.resolve()
    }

    @objc func pause(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        audioAsset.pause()
        call.resolve()
    }

    @objc func stop(_ call: CAPPluginCall) {
        let audioId = call.getString(Constant.AssetIdKey) ?? ""

        do {
            try stopAudio(audioId: audioId)
            call.resolve()
        } catch {
            call.reject(Constant.ErrorAssetNotFound)
        }
    }


    @objc func loop(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        audioAsset.loop()
        call.resolve()
    }

    @objc func unload(_ call: CAPPluginCall) {
        let audioId = call.getString(Constant.AssetIdKey) ?? ""
        if self.audioList.count > 0 {
            let asset = self.audioList[audioId]
            if asset != nil && asset is AudioAsset {
                let audioAsset = asset as! AudioAsset
                audioAsset.unload();
                self.audioList[audioId] = nil
            }
        }
        call.resolve()
    }

    @objc func setVolume(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        let volume = call.getFloat(Constant.Volume) ?? 1.0

        audioAsset.setVolume(volume: volume as NSNumber)
        call.resolve()
    }

    @objc func isPlaying(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        call.resolve([
            "isPlaying": audioAsset.isPlaying()
        ])
    }
    
    @objc func playQueue(_ call: CAPPluginCall) {
        print("playQueue")
        
        guard let jsTracks = call.getArray("tracks") else {
            call.reject("no tracks")
            return
        }
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        let index = call.getInt("startIndex", 0)
        let time = call.getDouble("startTime", 0.0)
        let trailingTimeSeconds = call.getDouble("trailingTime", 0.0)
        let timerUpdateInterval = call.getDouble("timerUpdateInterval", 1.0)
        let volume = call.getFloat("volume", 1.0)
        let loop = call.getBool("loop", true)
        let useFade = call.getBool("useFade", false)
        let current = queueControllers[queueId] ?? {
            let queueController = QueueController(owner: self, id: queueId, useFade: useFade)
            queueControllers[queueId] = queueController
            return queueController
        }()
        
        var jsTrackz : [[String: Any]] = []
        for i in 0 ..< jsTracks.count {
            let track = jsTracks[i] as! JSObject
            var dictionary: [String: Any] = [:]
            dictionary["id"] = String(track["id"] as? Int ?? 0)
            dictionary["url"] = track["url"] as? String ?? ""
            dictionary["name"] = track["name"] as? String ?? ""
            dictionary["isMusic"] = (track["isMusic"] as? Int ?? 0) == 1
            dictionary["forcePlay"] = (track["forcePlay"] as? Int ?? 0) == 1
            jsTrackz.append(track)
        }

        current.playQueue(
            jsTracks: jsTrackz,
            startIndex: index,
            startTime: time,
            trailingTimeSeconds: trailingTimeSeconds,
            timerUpdateInterval: timerUpdateInterval,
            volume: volume,
            loop: loop
        )
        call.resolve()
    }
    
    @objc func pauseQueue(_ call: CAPPluginCall) {
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        guard let result = queueControllers[queueId]?.pause()  else {
            call.reject("no queue")
            return
        }
        if result {
            call.resolve()
            return
        }
        call.reject("did not pause")
    }
    
    @objc func resumeQueue(_ call: CAPPluginCall) {
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        guard let result = queueControllers[queueId]?.resume() else {
            call.reject("no queue")
            return
        }
        if result {
            call.resolve()
            return
        }
        call.reject("did not resume")
    }
    
    @objc func isQueuePlaying(_ call: CAPPluginCall) {
        print("isQueuePlaying")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        guard let queue = queueControllers[queueId] else {
            call.resolve(["isQueuePlaying": false])
            return
        }
        
        call.resolve([
            "isQueuePlaying" : queue.isPlaying()
        ])
    }
    
    @objc func isQueuePaused(_ call: CAPPluginCall) {
        print("isQueuePaused")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        
        guard let queue = queueControllers[queueId] else {
            call.resolve(["isQueuePaused": false])
            return
        }
        
        call.resolve([
            "isQueuePaused" : queue.isPaused()
        ])
    }
    
    @objc func seekQueue(_ call: CAPPluginCall) {
        print("seekQueue")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        guard let time = call.getDouble("time") else {
            call.reject("no time")
            return
        }
        
        guard let result = queueControllers[queueId]?.seek(time: time) else {
            call.reject("no queue")
            return
        }
        if result {
            call.resolve()
            return
        }
        call.reject("did not seek")
    }
    
    @objc func playNextQueueTrack(_ call: CAPPluginCall) {
        print("playNextQueueTrack")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        
        guard let result = queueControllers[queueId]?.toNextTrack() else {
            call.reject("no queue")
            return
        }
        if result {
            call.resolve()
            return
        }
        call.reject("did not move to next track")
    }
    
    @objc func playPreviousQueueTrack(_ call: CAPPluginCall) {
        print("playPreviousQueueTrack")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        
        guard let result = queueControllers[queueId]?.toPreviousTrack() else {
            call.reject("no queue")
            return
        }
        if result {
            call.resolve()
            return
        }
        call.reject("did not move to previous track")
    }
    
    @objc func getQueuePlayingIndex(_ call: CAPPluginCall) {
        print("getQueuePlayingIndex")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        
        guard let result = queueControllers[queueId]?.index else {
            call.reject("no queue")
            return
        }
        call.resolve([
            "index": result
        ])
    }
    
    @objc func getQueuePlayingTrackId(_ call: CAPPluginCall) {
        print("getQueuePlayingTrackId")
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        
        let trackId = queueControllers[queueId]?.player?.getPlayingTrackId()
        call.resolve([
            "trackId" : trackId ?? ""
        ])
    }
    
        
    @objc func setQueueLoopIndex(_ call: CAPPluginCall) {
        print("setQueueLoopIndex")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
    
        guard let set = call.getBool("set") else {
            call.reject("no set value")
            return
        }
        
        guard let index = call.getInt("index") else {
            call.reject("no index")
            return
        }
        
        
        guard let queue = queueControllers[queueId] else {
            call.reject("no queue")
            return
        }
        
        queue.setLoopIndex(index: index, set: set)
        call.resolve()
    }
    
    @objc func setQueueVolume(_ call: CAPPluginCall) {
        print("setQueueVolume")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        
        guard let volume = call.getFloat("volume") else {
            call.reject("no volume")
            return
        }
        
        guard let queue = queueControllers[queueId] else {
            call.reject("no queue")
            return
        }
        
        let result = queue.setVolume(volume: volume)
        if !result {
            call.reject("did not set volume")
            return
        }
        call.resolve()
    }
    
    @objc func queueHasTrackWith(_ call: CAPPluginCall) {
        print("queueHasTrackWith")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        
        guard let url = call.getString("url") else {
            call.reject("no url")
            return
        }
        
        guard let queue = queueControllers[queueId] else {
            call.reject("no queue")
            return
        }
        
        let result = queue.queueHasAssetId(assetId: url)
        
        call.resolve(["has" : result])
    }
    
       
    @objc func updateQueue(_ call: CAPPluginCall) {
        print("updateQueue")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        
        guard let jsTracks = call.getArray("tracks") else {
            call.reject("no tracks")
            return
        }
        
        var jsTrackz : [[String: Any]] = []
        for i in 0 ..< jsTracks.count {
            let track = jsTracks[i] as! JSObject
            var dictionary: [String: Any] = [:]
            dictionary["id"] = String(track["id"] as? Int ?? 0)
            dictionary["url"] = track["url"] as? String ?? ""
            dictionary["name"] = track["name"] as? String ?? ""
            dictionary["isMusic"] = (track["isMusic"] as? Int ?? 0) == 1
            dictionary["forcePlay"] = (track["forcePlay"] as? Int ?? 0) == 1
            jsTrackz.append(track)
        }

        
        guard let queue = queueControllers[queueId] else {
            call.reject("no queue")
            return
        }
        
        queue.updateQueue(jsTracks: jsTrackz)
        call.resolve()
    }
    
    @objc func unloadQueue(_ call: CAPPluginCall) {
        print("unloadQueue")
        
        guard let queueId = call.getString("id") else {
            call.reject("no id")
            return
        }
        
        guard let queue = queueControllers[queueId] else {
            call.reject("no queue")
            return
        }
        
        queue.unload()
        queueControllers[queueId] = nil
        call.resolve()
    }
    
    @objc func setSleepTimer(_ call: CAPPluginCall) {
        print("setSleepTimer")
        
        guard let time = call.getDouble("time") else {
            call.reject("no time")
            return
        }
        
        sleepTimer?.invalidate()
        sleepTimer = Timer2(interval: time, function: { [weak self] in
            guard let self = self else { return }
            sleepTimer?.invalidate()
            stopAllQueues()
        })
        sleepTimer!.start()
        call.resolve()
    }
    
    @objc func cancelSleepTimer(_ call: CAPPluginCall) {
        print("cancelSleepTimer")
        
        sleepTimer?.invalidate()
        call.resolve()
    }

    private func preloadAsset(_ call: CAPPluginCall, isComplex complex: Bool) {
        let audioId = call.getString(Constant.AssetIdKey) ?? ""
        let channels: NSNumber?
        let volume: Float?
        let delay: NSNumber?

        if audioId != "" {
            let assetPath: String = call.getString(Constant.AssetPathKey) ?? ""

            if (complex) {
                volume = call.getFloat("volume") ?? 1.0
                channels = NSNumber(value: call.getInt("channels") ?? 1)
                delay = NSNumber(value: call.getInt("delay") ?? 1)

            } else {
                channels = 0
                volume = 0
                delay = 0

            }

            if audioList.isEmpty {
                audioList = [:]
            }

            let asset = audioList[audioId]
            let queue = DispatchQueue(label: "com.getcapacitor.community.audio.simple.queue", qos: .userInitiated)

            queue.async {
//                if asset == nil {
//                    let audioAsset: AudioAsset = AudioAsset(owner: self, withAssetId: audioId, withPath: assetPath, withChannels: channels, withVolume: volume as NSNumber?, withFadeDelay: delay)
//                                                self.audioList[audioId] = audioAsset
//                                                call.resolve()
//                } else {
//                    call.reject(Constant.ErrorAssetExists)
//                }
            }
        }
    }

    private func stopAudio(audioId: String) throws {
        if self.audioList.count > 0 {
            let asset = self.audioList[audioId]

            if asset != nil {
                if asset is AudioAsset {
                    let audioAsset = asset as? AudioAsset

                    if self.fadeMusic {
                        audioAsset?.playWithFade(time: audioAsset?.getCurrentTime() ?? 0)
                    } else {
                        audioAsset?.stop()
                    }
                }
            } else {
                throw MyError.runtimeError(Constant.ErrorAssetNotFound)
            }
        }
    }

    private func stopAllQueues() {
        for (_, controller) in queueControllers {
            controller.unload()
        }
        queueControllers = [:]
        notifyListeners(QueueController.kEventAllTracksStop, data: [:])
    }
}
