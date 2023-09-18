package com.getcapacitor.community.audio.queue

import com.getcapacitor.JSObject
import com.getcapacitor.community.audio.NativeAudio
import com.getcapacitor.community.audio.service.ForegroundServiceController
import org.json.JSONObject

class QueueController(private val owner: NativeAudio, val id: String, val useFade: Boolean) {

    companion object {
        const val EVENT_PLAYING = "track-playing"
        const val EVENT_TRACK_STOP = "track-stop"
        const val EVENT_ALL_TRACKS_STOP = "all-tracks-stop"
    }

    private val tracks: MutableList<QueueTrack> = mutableListOf()
    var index: Int = 0
    private var queueState: QueueState = QueueState.IDLE
    private var looping = false
    var player: QueuePlayer? = null
    private var loopIndex: Int = -1

    init {

    }


    fun playQueue(
        jsTracks: List<JSObject>,
        startIndex: Int,
        startTime: Double,
        trailingTimeSeconds: Double,
        timerUpdateInterval: Double,
        volume: Float,
        loop: Boolean,
        callback: () -> Unit) {
        if (startIndex >= jsTracks.size) {
            callback()
            return
        }
        owner.queueHandler.postTask {
            tracks.clear()

            for (i in jsTracks.indices) {
                var jsTrack = jsTracks[i] as JSONObject
                var track = QueueTrack(jsTrack)
                tracks.add(track)
            }

            this.looping = loop
            this.loopIndex = -1

            player?.unload()
            index = startIndex

            if (tracks.isEmpty()) {
                queueState = QueueState.IDLE
                return@postTask
            }

            player = QueuePlayer(
                owner = this.owner,
                queueController = this,
                trailingTimeSeconds = trailingTimeSeconds,
                timerUpdateInterval = timerUpdateInterval,
                useFade = useFade)
            player!!.setVolume(volume)

            var track = tracks[index]
            player!!.playTrack(track, startTime)
            callback()
        }
    }

    fun pause(callback: (Boolean) -> Unit) {
        owner.queueHandler.postTask {
            if (player?.isPlaying() != true) {
                callback(false)
                return@postTask
            }
            player?.pause()
            callback(true)
        }
    }

    fun resume(callback: (Boolean) -> Unit) {
        owner.queueHandler.postTask {
            if (player?.isPaused() != true) {
                callback(false)
                return@postTask
            }
            player?.resume()
            callback(true)
        }
    }

    fun isPlaying(callback: (Boolean) -> Unit) {
        owner.queueHandler.postTask {
            callback(player?.isPlaying() == true)
        }
    }

    fun isPaused(callback: (Boolean) -> Unit) {
        owner.queueHandler.postTask {
            callback(player?.isPaused() == true)
        }
    }

    fun getCurrentIndex(callback: (Int) -> Unit) {
        owner.queueHandler.postTask {
            callback(index)
        }
    }

    fun toNextTrack(callback: (Boolean) -> Unit) {
        owner.queueHandler.postTask {
            val nextTrack = requestNextTrackInternal()
            if (nextTrack == null) {
                callback(false)
                return@postTask
            }
            player?.unload()
            player?.playTrack(nextTrack)
            callback(true)
        }
    }

    fun toPreviousTrack(callback: (Boolean) -> Unit) {
        owner.queueHandler.postTask {
            val previousTrack = requestPreviousTrackInternal()
            if (previousTrack == null) {
                callback(false)
                return@postTask
            }
            player?.unload()
            player?.playTrack(previousTrack)
            callback(true)
        }
    }

    fun seek(time: Double, callback: (Boolean) -> Unit) {
        owner.queueHandler.postTask {
            if (player?.isPlaying() != true && player?.isPaused() != true) {
                callback(false)
                return@postTask
            }

            player?.seek(time)
            callback(true)
        }
    }

    fun getCurrentTime(): Double {
        return player?.getCurrentTime() ?: 0.0
    }

    fun setLoopIndex(index: Int, set: Boolean, callback: (Boolean) -> Unit) {
        owner.queueHandler.postTask {
            if (loopIndex > tracks.size - 1) {
                callback(false)
                return@postTask
            }

            loopIndex = if (set) index else -1

            if (loopIndex >= 0 && this.index != loopIndex) {
                this.index = loopIndex
                player?.unload()
                player?.playTrack(track = tracks[index])
            }
        }
    }

    fun setVolume(volume: Float, callback: (Boolean) -> Unit) {
        owner.queueHandler.postTask {
            player?.setVolume(volume)
            callback(player != null)
        }
    }

    fun queueHasAssetId(assetId: String, callback: (Boolean) -> Unit) {
        owner.queueHandler.postTask {
            callback(tracks.find { it.assetId == assetId } != null)
        }
    }

    private fun manageIndexToNext(): Boolean {
        if (loopIndex >= 0) {
            index = loopIndex
            return true
        }
        if (index == tracks.size - 1) {
            index = 0
            if (looping) {
                return true
            }
            return false
        }
        index += 1
        return true
    }

    private fun manageIndexToPrevious() : Boolean {
        if (index == 0) {
            if (looping) {
                index = tracks.size - 1
                return true
            }
            return false
        }
        index -= 1
        return true
    }

    fun requestNextTrack(callback: (QueueTrack?) -> Unit) {
        owner.queueHandler.postTask {
            callback(requestNextTrackInternal())
        }
    }

    private fun requestNextTrackInternal() : QueueTrack? {
        if (manageIndexToNext()) {
            return tracks[index]
        }
        return null
    }

    private fun requestPreviousTrackInternal() : QueueTrack? {
        if (manageIndexToPrevious()) {
            return tracks[index]
        }
        return null
    }

    fun completion(assetId: String) {
        owner.queueHandler.postTask {
            if (tracks.find { it.assetId == assetId } == null) {
                return@postTask
            }

            if (player!!.trailingTimeSeconds == 0.0 && (loopIndex >= 0 || looping)) {
                player!!.unload()
                val nextTrack = requestNextTrackInternal()
                if (nextTrack != null) {
                    player!!.playTrack(nextTrack)
                } else {
                    notifyStop(assetId)
                }
                return@postTask
            }

            val isPlayingAssetId = player?.isPlayingAssetId(assetId) == true
            val isTrailingAssetId = player?.isTrailingAssetId(assetId) == true

            if (isTrailingAssetId && isPlayingAssetId && (loopIndex >= 0 || looping)) {
                player?.unload(assetId)
                return@postTask
            }

            if (isPlayingAssetId) {
                notifyStop(assetId)
            }
            player?.unload(assetId)
        }
    }

    fun error(assetId: String) {
        owner.queueHandler.postTask {
            if (tracks.find { it.assetId == assetId } == null) {
                return@postTask
            }
            queueState = QueueState.IDLE
            player?.unload()
            notifyStop(assetId)
        }
    }

    fun getCurrentTrack() : QueueTrack? {
        if (tracks.isEmpty()) {
            return null
        }
        if (index < 0 || index > tracks.size - 1) {
            return null
        }
        return tracks[index]
    }

    fun isPlaying() : Boolean {
        return player?.isPlaying() == true || player?.isPaused() == true
    }

    fun unload() {
        queueState = QueueState.IDLE
        player?.unload()
    }

    fun notifyStop(assetId: String) {
        val jsObject = JSObject()
        jsObject.put("assetId", assetId)
        owner.notifyEventListeners(EVENT_TRACK_STOP, jsObject)
    }

}
