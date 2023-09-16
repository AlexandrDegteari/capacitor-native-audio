package com.getcapacitor.community.audio

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.net.Uri
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.source.MediaSource
import com.google.android.exoplayer2.source.ProgressiveMediaSource
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector
import com.google.android.exoplayer2.upstream.AssetDataSource
import com.google.android.exoplayer2.upstream.DataSource
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory
import java.util.concurrent.Callable

class AudioDispatcher(context: Context, path: String?, assetFileDescriptor: AssetFileDescriptor?, volume: Float) : Player.Listener {
    private val TAG = "AudioDispatcher"
    private val context: Context
    private val exoPlayer: ExoPlayer
    private var owner: AudioAsset? = null
    var isPlaying = false
        private set
    private var isPrepared = false

    init {
        this.context = context.applicationContext
        val trackSelector = DefaultTrackSelector(context)
        exoPlayer = ExoPlayer.Builder(context).build()

        exoPlayer.addListener(this)
        if (path != null) {
            val uri = Uri.parse(path)
            val dataSourceFactory: DataSource.Factory = DefaultDataSourceFactory(context,
                    "ExoPlayer")
            val mediaSource: MediaSource = ProgressiveMediaSource.Factory(dataSourceFactory)
                    .createMediaSource(MediaItem.fromUri(uri))
            exoPlayer.setMediaSource(mediaSource)
            exoPlayer.prepare()
        } else if (assetFileDescriptor != null) {
            val factory = DataSource.Factory { AssetDataSource(context) }
            //            DataSpec dataSpec = new DataSpec(assetFileDescriptor.ur);
//            AssetDataSource assetDataSource = new AssetDataSource(context);
//            try {
//                assetDataSource.open(dataSpec);
//            } catch (IOException e) {
//                throw new Exception("Error opening asset file descriptor", e);
//            }
//            MediaSource mediaSource = new ExtractorMediaSource.Factory(factory)
//                    .createMediaSource(assetDataSource.getUri(), null, null);
//            exoPlayer.prepare(mediaSource);
        }
        exoPlayer.volume = volume
        exoPlayer.playWhenReady = false
    }

    fun setOwner(asset: AudioAsset?) {
        owner = asset
    }

    val duration: Double
        get() {
            if (isPrepared) {
                val durationMillis = exoPlayer.duration
                return durationMillis.toDouble() / 1000.0
            }
            return 0.0
        }
    val currentPosition: Double
        get() {
            val currentPositionMillis = exoPlayer.currentPosition
            return currentPositionMillis.toDouble() / 1000.0
        }

    @Throws(Exception::class)
    fun play(time: Double, callable: Callable<Void?>?) {
        exoPlayer.seekTo(time.toLong() * 1000)
        exoPlayer.playWhenReady = true
    }

    @Throws(Exception::class)
    fun pause(): Boolean {
        if (isPlaying) {
            exoPlayer.playWhenReady = false
            return true
        }
        return false
    }

    @Throws(Exception::class)
    fun resume() {
        exoPlayer.playWhenReady = true
    }

    @Throws(Exception::class)
    fun stop(): Boolean {
        if (exoPlayer.playWhenReady) {
            exoPlayer.playWhenReady = false
            exoPlayer.seekTo(0)
            return true
        }
        return false
    }

    @Throws(Exception::class)
    fun setVolume(volume: Float) {
        exoPlayer.volume = volume
    }

    fun seekTo(time: Double) {
        exoPlayer.seekTo((time * 1000).toLong())
    }

    @Throws(Exception::class)
    fun loop() {
        exoPlayer.repeatMode = ExoPlayer.REPEAT_MODE_ALL
    }

    @Throws(Exception::class)
    fun unload() {
        stop()
        exoPlayer.removeListener(this)
        exoPlayer.release()
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        if (playbackState == Player.STATE_READY) {
            isPrepared = true
            owner!!.prepareComplete()
        } else if (playbackState == Player.STATE_ENDED) {
            owner!!.owner.queueHandler.postTask { owner!!.queueController?.completion(owner!!.assetId) }
        }
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        this.isPlaying = isPlaying
        owner!!.playingChanged(isPlaying)
        if (isPlaying) {
            owner!!.owner.foregroundServiceController.playerStartedPlaying(owner!!.queueTrack)
            return
        }
        owner!!.owner.foregroundServiceController.playerStoppedPlaying(owner!!.queueTrack)
    }
}
