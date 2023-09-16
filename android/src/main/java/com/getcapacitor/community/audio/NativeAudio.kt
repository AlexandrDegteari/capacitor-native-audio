package com.getcapacitor.community.audio

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.AssetFileDescriptor
import android.media.AudioManager
import android.media.AudioManager.OnAudioFocusChangeListener
import android.util.Log
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import com.getcapacitor.annotation.Permission
import com.getcapacitor.community.audio.queue.HandlerThread
import com.getcapacitor.community.audio.queue.QueueController
import com.getcapacitor.community.audio.queue.QueueTrack
import com.getcapacitor.community.audio.service.ForegroundServiceController
import com.getcapacitor.community.audio.service.NowPlayingBroadcastReceiver
import java.util.*

@CapacitorPlugin(permissions = [Permission(strings = [Manifest.permission.MODIFY_AUDIO_SETTINGS]), Permission(strings = [Manifest.permission.WRITE_EXTERNAL_STORAGE]), Permission(strings = [Manifest.permission.READ_PHONE_STATE])])
class NativeAudio : Plugin(), OnAudioFocusChangeListener {
    private var fadeMusic = false
    private var audioManager: AudioManager? = null

    private var queueControllers: MutableMap<String, QueueController> = mutableMapOf()
    var isInBackground = false

    @JvmField
    var queueHandler = HandlerThread("playing-queue")

    @JvmField
    var foregroundServiceController = ForegroundServiceController(this)
    private var sleepTimer: Timer? = null

    init {
        queueHandler.start()
        queueHandler.prepareHandler()



//        queueController = QueueController(this)
    }

    override fun load() {
        queueHandler.postTask {
            super.load()
            audioManager = getBridge().activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (audioManager != null) {
                audioManager!!.requestAudioFocus(this, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
            }
            val filter = IntentFilter()
            filter.addAction(getBridge().activity.packageName + ".stop_all")
            getBridge().activity.registerReceiver(object: BroadcastReceiver() {
                override fun onReceive(p0: Context?, p1: Intent?) {
                    Log.d(TAG, "on receive stop-all")
                    for ((_, queueController) in queueControllers) {
                        queueController.unload()
                    }
                    queueHandler.postTask { notifyListeners(QueueController.EVENT_ALL_TRACKS_STOP, JSObject()) }

                }
            }, filter)
        }
    }

    override fun onAudioFocusChange(focusChange: Int) {
        if (focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
        } else if (focusChange == AudioManager.AUDIOFOCUS_GAIN) {
        } else if (focusChange == AudioManager.AUDIOFOCUS_LOSS) {
        }
    }

    override fun handleOnPause() {
        isInBackground = true
    }

    override fun handleOnResume() {
        isInBackground = false
    }

    @PluginMethod
    fun configure(call: PluginCall) {
        queueHandler.postTask {
            initSoundPool()
            if (call.hasOption(Constant.OPT_FADE_MUSIC)) fadeMusic = call.getBoolean(Constant.OPT_FADE_MUSIC)!!
            if (call.hasOption(Constant.OPT_FOCUS_AUDIO) && audioManager != null) {
                if (call.getBoolean(Constant.OPT_FOCUS_AUDIO)!!) {
                    audioManager!!.requestAudioFocus(this, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
                } else {
                    audioManager!!.abandonAudioFocus(this)
                }
            }
        }
    }

    @PluginMethod
    fun preload(call: PluginCall) {
        queueHandler.postTask { preloadAsset(call) }
    }

    @PluginMethod
    fun play(call: PluginCall) {
        queueHandler.postTask { playOrLoop("play", call) }
    }

    @PluginMethod
    fun getCurrentTime(call: PluginCall) {
        queueHandler.postTask {
            try {
                initSoundPool()
                val audioId = call.getString(Constant.ASSET_ID)
                if (!isStringValid(audioId)) {
                    call.reject(Constant.ERROR_AUDIO_ID_MISSING + " - " + audioId)
                    return@postTask
                }
                if (audioAssetList!!.containsKey(audioId)) {
                    val asset = audioAssetList!![audioId]
                    if (asset != null) {
                        call.resolve(JSObject().put("currentTime", asset.currentPosition))
                    }
                } else {
                    call.reject(Constant.ERROR_AUDIO_ASSET_MISSING + " - " + audioId)
                }
            } catch (ex: Exception) {
                call.reject(ex.message)
            }
        }
    }

    @PluginMethod
    fun getDuration(call: PluginCall) {
        queueHandler.postTask {
            try {
                initSoundPool()
                val audioId = call.getString(Constant.ASSET_ID)
                if (!isStringValid(audioId)) {
                    call.reject(Constant.ERROR_AUDIO_ID_MISSING + " - " + audioId)
                    return@postTask
                }
                if (audioAssetList!!.containsKey(audioId)) {
                    val asset = audioAssetList!![audioId]
                    if (asset != null) {
                        val duration = asset.duration
                        val jsObject = JSObject()
                        jsObject.put("duration", duration)
                        call.resolve(jsObject)
                    }
                } else {
                    call.reject(Constant.ERROR_AUDIO_ASSET_MISSING + " - " + audioId)
                }
            } catch (ex: Exception) {
                call.reject(ex.message)
            }
        }
    }

    @PluginMethod
    fun loop(call: PluginCall) {
        queueHandler.postTask { playOrLoop("loop", call) }
    }

    @PluginMethod
    fun pause(call: PluginCall) {
        queueHandler.postTask {
            try {
                initSoundPool()
                val audioId = call.getString(Constant.ASSET_ID)
                if (audioAssetList!!.containsKey(audioId)) {
                    val asset = audioAssetList!![audioId]
                    if (asset != null) {
                        val wasPlaying = asset.pause()
                        if (wasPlaying) {
                            resumeList!!.add(asset)
                        }
                        call.resolve()
                    }
                } else {
                    call.reject(Constant.ERROR_ASSET_NOT_LOADED + " - " + audioId)
                }
            } catch (ex: Exception) {
                call.reject(ex.message)
            }
        }
    }

    @PluginMethod
    fun resume(call: PluginCall) {
        queueHandler.postTask {
            try {
                initSoundPool()
                val audioId = call.getString(Constant.ASSET_ID)
                if (audioAssetList!!.containsKey(audioId)) {
                    val asset = audioAssetList!![audioId]
                    if (asset != null) {
                        asset.resume()
                        resumeList!!.add(asset)
                        call.resolve()
                    }
                } else {
                    call.reject(Constant.ERROR_ASSET_NOT_LOADED + " - " + audioId)
                }
            } catch (ex: Exception) {
                call.reject(ex.message)
            }
        }
    }

    @PluginMethod
    fun stop(call: PluginCall) {
        queueHandler.postTask {
            try {
                initSoundPool()
                val audioId = call.getString(Constant.ASSET_ID)
                if (audioAssetList!!.containsKey(audioId)) {
                    val asset = audioAssetList!![audioId]
                    if (asset != null) {
                        asset.stop()
                        call.resolve()
                    }
                } else {
                    call.reject(Constant.ERROR_ASSET_NOT_LOADED + " - " + audioId)
                }
            } catch (ex: Exception) {
                call.reject(ex.message)
            }
        }
    }

    @PluginMethod
    fun unload(call: PluginCall) {
        queueHandler.postTask {
            try {
                initSoundPool()
                JSObject()
                val status: JSObject
                if (isStringValid(call.getString(Constant.ASSET_ID))) {
                    val audioId = call.getString(Constant.ASSET_ID)
                    if (audioAssetList!!.containsKey(audioId)) {
                        val asset = audioAssetList!![audioId]
                        if (asset != null) {
                            asset.unload()
                            audioAssetList!!.remove(audioId)
                            status = JSObject()
                            status.put("status", "OK")
                            call.resolve(status)
                        } else {
                            status = JSObject()
                            status.put("status", false)
                            call.resolve(status)
                        }
                    } else {
                        status = JSObject()
                        status.put("status", Constant.ERROR_AUDIO_ASSET_MISSING + " - " + audioId)
                        call.resolve(status)
                    }
                } else {
                    status = JSObject()
                    status.put("status", Constant.ERROR_AUDIO_ID_MISSING)
                    call.resolve(status)
                }
            } catch (ex: Exception) {
                call.reject(ex.message)
            }
        }
    }

    @PluginMethod
    fun setVolume(call: PluginCall) {
        queueHandler.postTask {
            try {
                initSoundPool()
                val audioId = call.getString(Constant.ASSET_ID)
                val volume = call.getFloat(Constant.VOLUME)!!
                if (audioAssetList!!.containsKey(audioId)) {
                    val asset = audioAssetList!![audioId]
                    if (asset != null) {
                        asset.setVolume(volume)
                        call.resolve()
                    }
                } else {
//                    queueController.queueHasAssetId(audioId!!) { has: Boolean ->
//                        if (has) {
//                            queueController.setVolume(volume) { didSet: Boolean ->
//                                if (didSet) {
//                                    call.resolve()
//                                } else {
//                                    call.reject("")
//                                }
//                                null
//                            }
//                        } else {
//                            call.reject(Constant.ERROR_AUDIO_ASSET_MISSING)
//                        }
//                        null
//                    }
                }
            } catch (ex: Exception) {
                call.reject(ex.message)
            }
        }
    }

    @PluginMethod
    fun isPlaying(call: PluginCall) {
        queueHandler.postTask {
            try {
                initSoundPool()
                val audioId = call.getString(Constant.ASSET_ID)
                if (!isStringValid(audioId)) {
                    call.reject(Constant.ERROR_AUDIO_ID_MISSING + " - " + audioId)
                    return@postTask
                }
                if (audioAssetList!!.containsKey(audioId)) {
                    val asset = audioAssetList!![audioId]
                    if (asset != null) {
                        call.resolve(JSObject().put("isPlaying", asset.isPlaying))
                    }
                } else {
                    call.reject(Constant.ERROR_AUDIO_ASSET_MISSING + " - " + audioId)
                }
            } catch (ex: Exception) {
                call.reject(ex.message)
            }
        }
    }

    // Queue Methods
    @PluginMethod
    fun playQueue(call: PluginCall) {
        try {
            val jsTracks = call.getArray("tracks")
            val queueId = call.getString("id")
            val index = call.getInt("startIndex", 0)!!
            val time = call.getDouble("startTime", 0.0)
            val trailingTimeSeconds = call.getDouble("trailingTime", 0.0)
            val timerUpdateInterval = call.getDouble("timerUpdateInterval", 1.0)
            val volume = call.getFloat("volume", 1.0f)!!
            val loop = call.getBoolean("loop", true)!!
            val useFade = call.getBoolean("useFade", false)!!
            val current = queueControllers[queueId] ?: run {
                val queueController = QueueController(this, queueId!!, useFade)
                queueControllers[queueId] = queueController
                return@run queueController
            }
            (current as QueueController).playQueue(jsTracks.toList(), index, time!!, trailingTimeSeconds!!, timerUpdateInterval!!, volume, loop) {
                call.resolve()
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun pauseQueue(call: PluginCall) {
        try {
            val queueId = call.getString("id")
            queueControllers[queueId]!!.pause { paused: Boolean ->
                if (paused) {
                    call.resolve()
                } else {
                    call.reject("")
                }
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun resumeQueue(call: PluginCall) {
        try {
            val queueId = call.getString("id")
            queueControllers[queueId]!!.resume { resumed: Boolean ->
                if (resumed) {
                    call.resolve()
                } else {
                    call.reject("")
                }
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun isQueuePlaying(call: PluginCall) {
        try {
            val queueId = call.getString("id")
            queueControllers[queueId]!!.isPlaying { playing: Boolean? ->
                call.resolve(JSObject().put("isQueuePlaying", playing))
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun isQueuePaused(call: PluginCall) {
        try {
            val queueId = call.getString("id")
            queueControllers[queueId]?.isPaused { paused: Boolean? ->
                call.resolve(JSObject().put("isQueuePaused", paused))
            } ?: run {
                call.resolve(JSObject().put("isQueuePaused", false))
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun seekQueue(call: PluginCall) {
        try {
            val time = call.getDouble("time", 0.0)
            val queueId = call.getString("id")
            queueControllers[queueId]!!.seek(time!!) { seeked: Boolean ->
                if (seeked) {
                    call.resolve()
                } else {
                    call.reject("")
                }
            }
            call.resolve()
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun playNextQueueTrack(call: PluginCall) {
        try {
            val queueId = call.getString("id")
            queueControllers[queueId]!!.toNextTrack { movedToNext: Boolean ->
                if (movedToNext) {
                    call.resolve()
                } else {
                    call.reject("")
                }
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun playPreviousQueueTrack(call: PluginCall) {
        try {
            val queueId = call.getString("id")
            queueControllers[queueId]!!.toPreviousTrack { movedToPrevious: Boolean ->
                if (movedToPrevious) {
                    call.resolve()
                } else {
                    call.reject("")
                }
                null
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun getQueueTrackCurrentTime(call: PluginCall) {
        try {
            call.resolve()
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun getQueuePlayingIndex(call: PluginCall) {
        try {
            val queueId = call.getString("id")
            if (queueId == null) {
                call.reject("no index")
                return
            }
            val index = queueControllers[queueId]?.index
            if (index == null) {
                call.resolve(JSObject().put("index", -1))
                return
            }
            call.resolve(JSObject().put("index", index))
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun setQueueLoopIndex(call: PluginCall) {
        try {
            val loopIndex = call.getInt("index", -1)!!
            val set = call.getBoolean("set", false)!!
            val queueId = call.getString("id")
            queueControllers[queueId]!!.setLoopIndex(loopIndex, set) { didSet: Boolean ->
                if (didSet) {
                    call.resolve()
                } else {
                    call.reject("")
                }
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun setQueueVolume(call: PluginCall) {
        try {
            val volume = call.getFloat(Constant.VOLUME, 1.0f)!!
            val queueId = call.getString("id")
            queueControllers[queueId]!!.setVolume(volume) { didSet: Boolean ->
                if (didSet) {
                    call.resolve()
                } else {
                    call.reject("")
                }
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun queueHasTrackWith(call: PluginCall) {
        try {
            val url = call.getString("url", "")
            val queueId = call.getString("id")
            queueControllers[queueId]!!.queueHasAssetId(url!!) { has: Boolean? ->
                call.resolve(JSObject().put("has", has))
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun unloadQueue(call: PluginCall) {
        queueHandler.postTask {
            try {
                val queueId = call.getString("id")
                val queue = queueControllers[queueId]
                if (queue == null) {
                    call.reject("")
                    return@postTask
                }
                queue.unload()
                queueControllers.remove(queueId)
            } catch (ex: Exception) {
                call.reject(ex.message)
            }
        }

    }

    // Queue methods END
    @PluginMethod
    fun setSleepTimer(call: PluginCall) {
        try {
            if (!call.hasOption("time")) {
                call.reject("No time set")
                return
            }
            val time = call.getInt("time", 0)!!
            if (sleepTimer != null) {
                sleepTimer!!.cancel()
            }
            sleepTimer = Timer()
            sleepTimer!!.schedule(object : TimerTask() {
                override fun run() {
                    for ((_, queueController) in queueControllers) {
                        queueController.pause { paused: Boolean? -> null }
                    }
                    try {
                        if (audioAssetList != null) {
                            for (key in audioAssetList!!.keys) {
                                val asset = audioAssetList!![key]
                                asset?.unload()
                            }
                            audioAssetList!!.clear()
                        }
                        queueHandler.postTask { notifyListeners(QueueController.EVENT_ALL_TRACKS_STOP, JSObject()) }
                    } catch (e: Exception) {
                        Log.d("ex", e.message!!)
                    }
                }
            }, (time * 1000).toLong())
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    @PluginMethod
    fun cancelSleepTimer(call: PluginCall) {
        try {
            if (sleepTimer != null) {
                sleepTimer!!.cancel()
                call.resolve()
                return
            }
            call.reject("no timer was set")
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    fun dispatchComplete(assetId: String?) {
        val ret = JSObject()
        ret.put("assetId", assetId)
        notifyListeners("complete", ret)
    }

    fun prepareComplete(assetId: String?) {
        val ret = JSObject()
        ret.put("assetId", assetId)
        notifyListeners("prepareComplete", ret)
    }

    fun notifyPlaying(time: Double, duration: Double, queueId: String, index: Int) {
        val jsObject = JSObject()
        jsObject.put("time", time)
        jsObject.put("duration", duration)
        jsObject.put("id", queueId)
        jsObject.put("index", index)
        notifyEventListeners("track-playing", jsObject)
    }

    fun notifyPause(time: Double, duration: Double, queueId: String, index: Int) {
        val jsObject = JSObject()
        jsObject.put("time", time)
        jsObject.put("duration", duration)
        jsObject.put("id", queueId)
        jsObject.put("index", index)
        notifyEventListeners("track-pause", jsObject)
    }

    fun notifyEventListeners(event: String, value: JSObject?) {
        if (event == QueueController.EVENT_PLAYING && isInBackground) {
            return
        }
        notifyListeners(event, value)
    }

    private fun preloadAsset(call: PluginCall) {
        var volume = 1.0
        var audioChannelNum = 1
        try {
            initSoundPool()
            val audioId = call.getString(Constant.ASSET_ID)
            val isUrl = call.getBoolean("isUrl", false)!!
            if (!isStringValid(audioId)) {
                call.reject(Constant.ERROR_AUDIO_ID_MISSING + " - " + audioId)
                return
            }
            if (!audioAssetList!!.containsKey(audioId)) {
                val assetPath = call.getString(Constant.ASSET_PATH)
                if (!isStringValid(assetPath)) {
                    call.reject(Constant.ERROR_ASSET_PATH_MISSING + " - " + audioId + " - " + assetPath)
                    return
                }
                volume = if (call.getDouble(Constant.VOLUME) == null) {
                    1.0
                } else {
                    call.getDouble(Constant.VOLUME, 0.5)!!
                }
                audioChannelNum = if (call.getInt(Constant.AUDIO_CHANNEL_NUM) == null) {
                    1
                } else {
                    call.getInt(Constant.AUDIO_CHANNEL_NUM)!!
                }
                var assetFileDescriptor: AssetFileDescriptor
                //                if (isUrl) {
//                    File f = new File(new URI(fullPath));
//                    ParcelFileDescriptor p = ParcelFileDescriptor.open(
//                            f,
//                            ParcelFileDescriptor.MODE_READ_ONLY
//                    );
//                    assetFileDescriptor = new AssetFileDescriptor(p, 0, -1);
//                } else {
//                    if (fullPath.startsWith("content")) {
//                        assetFileDescriptor = getBridge().getActivity().getContentResolver().openAssetFileDescriptor(Uri.parse(fullPath), "r");
//                    } else {
//                        Context ctx = getBridge().getActivity().getApplicationContext();
//                        AssetManager am = ctx.getResources().getAssets();
//                        assetFileDescriptor = am.openFd(fullPath);
//                    }
//                }
                val queueTrack = QueueTrack(assetPath!!, assetPath, false)
                val asset = AudioAsset(this, null, null, queueTrack, null, audioChannelNum, volume.toFloat())
                audioAssetList!![audioId] = asset
                val status = JSObject()
                status.put("STATUS", "OK")
                call.resolve(status)
            } else {
                call.reject(Constant.ERROR_AUDIO_EXISTS)
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    private fun playOrLoop(action: String, call: PluginCall) {
        try {
            initSoundPool()
            val audioId = call.getString(Constant.ASSET_ID)
            val time = call.getDouble("time", 0.0)
            if (audioAssetList!!.containsKey(audioId)) {
                val asset = audioAssetList!![audioId]
                if (Constant.LOOP == action && asset != null) {
                    asset.loop()
                } else asset?.play(time) {
                    call.resolve(JSObject().put(Constant.ASSET_ID, audioId))
                    null
                }
            }
        } catch (ex: Exception) {
            call.reject(ex.message)
        }
    }

    private fun initSoundPool() {
        if (audioAssetList == null) {
            audioAssetList = HashMap()
        }
        if (resumeList == null) {
            resumeList = ArrayList()
        }
    }

    private fun isStringValid(value: String?): Boolean {
        return value != null && !value.isEmpty() && value != "null"
    }

    companion object {
        const val TAG = "NativeAudio"
        private var audioAssetList: HashMap<String?, AudioAsset>? = null
        private var resumeList: ArrayList<AudioAsset>? = null
    }
}
