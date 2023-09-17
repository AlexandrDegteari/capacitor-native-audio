import { WebPlugin } from '@capacitor/core';
import type { ConfigureOptions, PreloadOptions, QueueTrack } from './definitions';
import { NativeAudio } from './definitions';
export declare class NativeAudioWeb extends WebPlugin implements NativeAudio {
    private static readonly FILE_LOCATION;
    private static readonly AUDIO_ASSET_BY_ASSET_ID;
    constructor();
    getQueuePlayingIndex(options: {
        id: string;
    }): Promise<number>;
    resume(options: {
        assetId: string;
    }): Promise<void>;
    pause(options: {
        assetId: string;
    }): Promise<void>;
    getCurrentTime(options: {
        assetId: string;
    }): Promise<{
        currentTime: number;
    }>;
    getDuration(options: {
        assetId: string;
    }): Promise<{
        duration: number;
    }>;
    configure(options: ConfigureOptions): Promise<void>;
    preload(options: PreloadOptions): Promise<void>;
    play(options: {
        assetId: string;
        time?: number;
    }): Promise<void>;
    loop(options: {
        assetId: string;
    }): Promise<void>;
    stop(options: {
        assetId: string;
    }): Promise<void>;
    unload(options: {
        assetId: string;
    }): Promise<void>;
    setVolume(options: {
        assetId: string;
        volume: number;
    }): Promise<void>;
    isPlaying(options: {
        assetId: string;
    }): Promise<{
        isPlaying: boolean;
    }>;
    private getAudioAsset;
    private checkAssetId;
    cancelSleepTimer(): Promise<void>;
    getCurrentQueueIndex(): Promise<number>;
    getQueueTrackCurrentTime(id: string): Promise<number>;
    isQueuePaused(options: {
        id: string;
    }): Promise<{
        isQueuePaused: boolean;
    }>;
    isQueuePlaying(options: {
        id: string;
    }): Promise<{
        isQueuePlaying: boolean;
    }>;
    pauseQueue(options: {
        id: string;
    }): Promise<void>;
    playNextQueueTrack(id: string): Promise<void>;
    playPreviousQueueTrack(id: string): Promise<void>;
    playQueue(options: {
        id: string;
        tracks: QueueTrack[];
        startIndex: number;
        startTime: number;
        trailingTime: number;
        timerUpdateInterval: number;
        volume: number;
        useFade: boolean;
        loop: boolean;
    }): Promise<void>;
    queueHasTrackWith(options: {
        id: string;
        url: string;
    }): Promise<{
        has: boolean;
    }>;
    resumeQueue(options: {
        id: string;
    }): Promise<void>;
    seekQueue(options: {
        id: string;
        time: number;
    }): Promise<void>;
    setQueueLoopIndex(options: {
        id: string;
        index: number;
        set: boolean;
    }): Promise<number>;
    setQueueVolume(options: {
        id: string;
        volume: number;
    }): Promise<void>;
    setSleepTimer(options: {
        time: number;
    }): Promise<void>;
    unloadQueue(options: {
        id: string;
    }): Promise<void>;
}
declare const NativeAudio: NativeAudioWeb;
export { NativeAudio };
