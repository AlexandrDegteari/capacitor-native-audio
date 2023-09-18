package com.getcapacitor.community.audio.service

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.text.TextUtils
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.getcapacitor.community.audio.nativeaudio.R

class NowPlayingService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            return START_NOT_STICKY
        }
        val what = intent.getIntExtra(WHAT_KEY, STOP_FOREGROUND)
        if (what == START_FOREGROUND) {
            val activityClss: Class<*>
            activityClss = try {
                Class.forName(intent.getStringExtra(ACTIVITY_CLASS_KEY))
            } catch (e: ClassNotFoundException) {
                throw RuntimeException(e)
            }
            val body = intent.getStringExtra(BODY_KEY)
            val stopTitle = intent.getStringExtra(STOP_TITLE_KEY)
            val notificationIntent = Intent(this, activityClss)
            val foregroundPendingIntent = PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
            )
            val CHANNEL_ID = "now_playing_channel_id"
            val soundUri = Uri.parse("android.resource://" + packageName + "/" + R.raw.silence)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val name: CharSequence = "Now playing"
                val importance = NotificationManager.IMPORTANCE_HIGH
                val channel = NotificationChannel("now_playing_channel_id", name, importance)
                val notificationManager = getSystemService(NotificationManager::class.java)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                channel.setSound(soundUri, audioAttributes)
                notificationManager.createNotificationChannel(channel)
            }

            val stopAllIntent = Intent(this, NowPlayingBroadcastReceiver::class.java).apply {
                action = NowPlayingBroadcastReceiver.ACTION_STOP_ALL
            }
            val stopAllPendingIntent: PendingIntent =
                PendingIntent.getBroadcast(this, 0, stopAllIntent, PendingIntent.FLAG_IMMUTABLE)
            val foregroundNotification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSilent(true)
                .setContentTitle(if (TextUtils.isEmpty(body)) "Playing..." else body) //                    .setContentText(TextUtils.isEmpty(body) ? "Playing..." : body)
                .setSmallIcon(R.drawable.dreamcatcher_icon_statusbar)
                .setContentIntent(foregroundPendingIntent)
                .setSound(soundUri)
                .setOngoing(true)
                .setShowWhen(false)
                .setOnlyAlertOnce(true)
                .addAction(NotificationCompat.Action(null, stopTitle ?: "Stop all", stopAllPendingIntent))
                .build()
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(FOREGROUND_ID, foregroundNotification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(FOREGROUND_ID, foregroundNotification)
            }
            return START_STICKY
        } else if (what == STOP_FOREGROUND) {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent): IBinder? {
        return null
    }

    companion object {
        private val TAG = NowPlayingService::class.java.simpleName
        private const val START_FOREGROUND = 0
        private const val STOP_FOREGROUND = 1
        private const val FOREGROUND_ID = 111
        private const val WHAT_KEY = "what"
        private const val ACTIVITY_CLASS_KEY = "activity-class"
        private const val BODY_KEY = "body"
        private const val STOP_TITLE_KEY = "stop-title"
        fun startCommand(context: Activity, start: Boolean, body: String?, stopTitle: String?) {
            val startCommandIntent = Intent(context, NowPlayingService::class.java)
            startCommandIntent.putExtra(WHAT_KEY, if (start) START_FOREGROUND else STOP_FOREGROUND)
            startCommandIntent.putExtra(STOP_TITLE_KEY, stopTitle)
            if (start && body != null) {
                startCommandIntent.putExtra(BODY_KEY, body)
            }
            if (start) {
                startCommandIntent.putExtra(ACTIVITY_CLASS_KEY, context.javaClass.name)
            }
            if (start && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(startCommandIntent)
                return
            }
            context.startService(startCommandIntent)
        }
    }
}