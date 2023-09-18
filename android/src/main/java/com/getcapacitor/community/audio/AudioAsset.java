package com.getcapacitor.community.audio;

import android.content.res.AssetFileDescriptor;
import android.util.Log;

import androidx.appcompat.app.AppCompatActivity;

import com.getcapacitor.community.audio.queue.QueueController;
import com.getcapacitor.community.audio.queue.QueuePlayer;
import com.getcapacitor.community.audio.queue.QueueTrack;

import java.util.ArrayList;
import java.util.concurrent.Callable;

public class AudioAsset {

    private final String TAG = "AudioAsset";

    private final ArrayList<AudioDispatcher> audioList;
    private int playIndex = 0;
    public final String assetId;
    final NativeAudio owner;
    final QueueController queueController;
    public final QueuePlayer queuePlayer;
    public final QueueTrack queueTrack;
    private boolean onPause = false;

    public AudioAsset(
            NativeAudio owner,
            QueueController queueController,
            QueuePlayer queuePlayer,
            QueueTrack queueTrack,
            AssetFileDescriptor assetFileDescriptor,
            int audioChannelNum,
            float volume
    )
            throws Exception {
        audioList = new ArrayList<>();
        this.owner = owner;
        this.queueController = queueController;
        this.queueTrack = queueTrack;
        this.queuePlayer = queuePlayer;
        this.assetId = queueTrack.getUrl();

        if (audioChannelNum < 0) {
            audioChannelNum = 1;
        }

        for (int x = 0; x < audioChannelNum; x++) {
            AudioDispatcher audioDispatcher = new AudioDispatcher(
                    owner.getActivity(),
                    queueTrack.getUrl(),
                    assetFileDescriptor,
                    volume
            );
            audioList.add(audioDispatcher);
            if (audioChannelNum == 1) audioDispatcher.setOwner(this);
        }
    }

    public void dispatchComplete() {
        this.owner.dispatchComplete(this.assetId);
    }

    public void prepareComplete() {

        this.owner.prepareComplete(this.assetId);

        Log.d(TAG, "prepare complete assetId " + this.assetId + " isPlaying " + this.audioList.get(0).isPlaying());
    }

    public void play(Double time, Callable<Void> callback) throws Exception {
        AudioDispatcher audio = audioList.get(playIndex);

        if (audio != null) {
            audio.play(time, callback);
            playIndex++;
            playIndex = playIndex % audioList.size();
        }
    }

    public double getDuration() {
        Log.d(TAG, "myLog getDuration");
        if (audioList.size() != 1) return 0;

        AudioDispatcher audio = audioList.get(playIndex);

        if (audio != null) {
            return audio.getDuration();
        }
        return 0;
    }

    public double getCurrentPosition() {
        if (audioList.size() != 1) return 0;

        AudioDispatcher audio = audioList.get(playIndex);

        if (audio != null) {
            return audio.getCurrentPosition();
        }
        return 0;
    }

    public boolean pause() throws Exception {
        boolean wasPlaying = false;

        for (int x = 0; x < audioList.size(); x++) {
            AudioDispatcher audio = audioList.get(x);
            wasPlaying |= audio.pause();
        }
        onPause = true;
        return wasPlaying;
    }

    public boolean isPaused() {
        return onPause;
    }

    public void resume() throws Exception {
        if (audioList.size() > 0) {
            AudioDispatcher audio = audioList.get(0);

            if (audio != null) {
                audio.resume();
            }
        }
        onPause = false;
    }

    public void stop() throws Exception {
        for (int x = 0; x < audioList.size(); x++) {
            AudioDispatcher audio = audioList.get(x);

            if (audio != null) {
                audio.stop();
            }
        }
    }

    public void loop() throws Exception {
        AudioDispatcher audio = audioList.get(playIndex);

        if (audio != null) {
            audio.play(0.0, null);
            audio.loop();
            playIndex++;
            playIndex = playIndex % audioList.size();
        }
    }

    public void unload() throws Exception {
        this.stop();

        for (int x = 0; x < audioList.size(); x++) {
            AudioDispatcher audio = audioList.get(x);

            if (audio != null) {
                audio.unload();
            }
        }

        audioList.clear();
    }

    public void setVolume(float volume) throws Exception {
        Log.d(TAG, "set volume " + volume);
        for (int x = 0; x < audioList.size(); x++) {
            AudioDispatcher audio = audioList.get(x);

            if (audio != null) {
                audio.setVolume(volume);
            }
        }
    }

    public void seek(double time) {
        for (int x = 0; x < audioList.size(); x++) {
            AudioDispatcher audio = audioList.get(x);

            if (audio != null) {
                audio.seekTo(time);
            }
        }
    }

    public boolean isPlaying() throws Exception {
        if (audioList.size() != 1) return false;

        return audioList.get(playIndex).isPlaying();
    }

    public void playingChanged(boolean isPlaying) {
        if (isPlaying) {
            queuePlayer.fadeIn(this);
        }

        queuePlayer.playingChanged(isPlaying);
    }

    public AppCompatActivity getActivity() {
        return owner.getBridge().getActivity();
    }
}

