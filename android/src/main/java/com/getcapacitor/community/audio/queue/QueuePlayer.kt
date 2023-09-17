package com.getcapacitor.community.audio.queue

import android.util.Log
import com.getcapacitor.community.audio.AudioAsset
import com.getcapacitor.community.audio.NativeAudio
import com.getcapacitor.community.audio.service.NowPlayingService
import java.util.*

class QueuePlayer(
        private val owner: NativeAudio,
        private val queueController: QueueController,
        val trailingTimeSeconds: Double,
        private val timerUpdateInterval: Double,
        private val useFade: Boolean
) {
    companion object {
        const val TAG = "QueuePlayer"
    }

    private var playing: AudioAsset? = null
    private var trailing: AudioAsset? = null
    private var timer: Timer? = null
    private var duration: Double = 0.0
    private var currentTime: Double = 0.0
    private var volume: Float = 1.0f
    private var unloaded = false

    fun playTrack(track: QueueTrack, time: Double = 0.0) {
        unload()
        unloaded = false
        startPlay(track, time)
        notifyPlaying()
    }

    private fun startPlay(track: QueueTrack, time: Double = 0.0) {
        playing = AudioAsset(owner, queueController, this, track, null, 1, volume);
        duration = playing!!.duration
        playing!!.play(time, null)
        currentTime = 0.0
        scheduleTimer()
    }

    fun pause() {
        timer?.cancel()
        trailing?.unload()
        playing?.pause()
        notifyPause()
    }

    fun resume() {
        playing?.resume()
        scheduleTimer()
    }

    fun getCurrentTime(): Double {
        return playing?.currentPosition ?: 0.0
    }

    fun isPlaying(): Boolean {
        return playing?.isPlaying == true
    }

    fun isPaused(): Boolean {
        return playing?.isPaused == true
    }

    fun seek(time: Double) {
        if (!isPaused() && !isPlaying()) {
            return
        }
        playing!!.seek(time)
        currentTime = time
        toNextOrNotify()
    }

    fun setVolume(volume: Float) {
        this.volume = volume
        this.playing?.setVolume(this.volume)
        this.trailing?.setVolume(this.volume)
    }

    fun unload() {
        timer?.cancel()
        timer = null
        playing?.unload()
        trailing?.unload()
        unloaded = true
    }

    fun unload(assetId: String) {
        if (trailing?.assetId == assetId) {
            trailing?.unload()
            return
        }
        if (playing?.assetId == assetId) {
            playing?.unload()
        }
    }

    fun isPlayingAssetId(assetId: String): Boolean {
        return playing?.assetId == assetId
    }

    fun isTrailingAssetId(assetId: String): Boolean {
        return trailing?.assetId == assetId
    }

    private fun scheduleTimer() {
        val updateInterval = (timerUpdateInterval * 1000).toLong()
        timer = Timer()
        timer!!.schedule(object : TimerTask() {
            override fun run() {
                owner.queueHandler.postTask {
                    advanceTimer()
                    Log.d("QueuePlayer", String.format("current time %f duration %f", currentTime, duration))
                }
            }

        }, updateInterval, updateInterval)
    }

    private fun advanceTimer() {
        duration = playing!!.duration;
        if (currentTime < duration) {
            currentTime = (playing?.currentPosition ?: 0.0)
            toNextOrNotify()
        }
    }

    private fun toNextOrNotify() {
        if (trailingTimeSeconds == 0.0) {
            notifyPlaying()
            return
        }
        if (duration - currentTime <= trailingTimeSeconds) {
            tryMoveToNext()
            return
        }
        if (playing?.isPlaying == false) {
            return
        }
        notifyPlaying()
    }

    private fun notifyPlaying() {
        if (unloaded) {
            return
        }
        val id = playing?.assetId ?: return
        owner.notifyPlaying(currentTime, duration, queueController.id, id, queueController.index)
    }

    private fun notifyPause() {
        if (unloaded) {
            return
        }
        owner.notifyPause(currentTime, duration, queueController.id, queueController.index)
    }

    fun fadeIn(audioAsset: AudioAsset) {
        if (!useFade) {
            return
        }
        val time = 1.0f
        val step = 0.05f
        var currentTime: Long = 0
        val volumeLimit: Float = this.volume
        val volumeStep: Float = 0.05f
        var currentVolume: Float = this.volume / 3

        audioAsset.setVolume(0.0f)

        var setVolume: (() -> Unit)? = null
        setVolume = {
            currentVolume = Math.min(currentVolume + volumeStep, volumeLimit)
            owner.queueHandler.postAfter({
                audioAsset.setVolume(currentVolume)
                Log.d(TAG, "setting volume to ${currentVolume} time ${currentTime}")
                if (currentVolume == volumeLimit) {
                    return@postAfter
                }
                currentTime += (step * 1000).toLong()

                setVolume?.invoke()
            }, (step * 1000).toLong())
        }
        setVolume.invoke()
    }

    fun fadeOut(audioAsset: AudioAsset) {
        if (!useFade) {
            return
        }
        val time = 1.0f
        val step = 0.1f
        var currentTime: Long = 0
        val targetVolume: Float = this.volume / 3
        val volumeStep: Float = 0.1f
        var currentVolume = this.volume

        audioAsset.setVolume(this.volume)

        var setVolume: (() -> Unit)? = null
        setVolume = {
            currentVolume = Math.max(currentVolume - volumeStep, targetVolume)
            owner.queueHandler.postAfter({
                audioAsset.setVolume(currentVolume)
                Log.d(TAG, "setting fade out volume to ${currentVolume} time ${currentTime}")
                if (currentVolume <= targetVolume) {
                    return@postAfter
                }
                currentTime += (step * 1000).toLong()

                setVolume?.invoke()
            }, (step * 1000).toLong())
        }
        setVolume.invoke()
    }

    fun playingChanged(isPlaying: Boolean) {
        if (!isPlaying && playing?.isPaused == true) {

        }
    }

    private fun tryMoveToNext() {
        queueController.requestNextTrack {
            if (it == null) {
                notifyPlaying()
                return@requestNextTrack
            }

            trailing?.unload()
            trailing = playing
            owner.queueHandler.postAfter({
                if (trailing != null) {
                    fadeOut(trailing!!)
                }
            }, 500)
            timer?.cancel()
            startPlay(it, 0.0)
        }
    }


}
