export interface NativeAudio {
    configure(options: ConfigureOptions): Promise<void>;
    preload(options: PreloadOptions): Promise<void>;
    play(options: {
        assetId: string;
        time: number;
    }): Promise<void>;
    pause(options: {
        assetId: string;
    }): Promise<void>;
    resume(options: {
        assetId: string;
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
    isPlaying(options: {
        assetId: string;
    }): Promise<{
        isPlaying: boolean;
    }>;
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
    pauseQueue(options: {
        id: string;
    }): Promise<void>;
    resumeQueue(options: {
        id: string;
    }): Promise<void>;
    isQueuePlaying(options: {
        id: string;
    }): Promise<{
        isQueuePlaying: boolean;
    }>;
    isQueuePaused(options: {
        id: string;
    }): Promise<{
        isQueuePaused: boolean;
    }>;
    seekQueue(options: {
        id: string;
        time: number;
    }): Promise<void>;
    playNextQueueTrack(id: string): Promise<void>;
    playPreviousQueueTrack(id: string): Promise<void>;
    getQueueTrackCurrentTime(id: string): Promise<number>;
    getQueuePlayingIndex(options: {
        id: string;
    }): Promise<number>;
    setQueueLoopIndex(options: {
        id: string;
        index: number;
        set: boolean;
    }): Promise<number>;
    setQueueVolume(options: {
        id: string;
        volume: number;
    }): Promise<void>;
    queueHasTrackWith(options: {
        id: string;
        url: string;
    }): Promise<{
        has: boolean;
    }>;
    unloadQueue(options: {
        id: string;
    }): Promise<void>;
    setSleepTimer(options: {
        time: number;
    }): Promise<void>;
    cancelSleepTimer(options: {}): Promise<void>;
}
export interface ConfigureOptions {
    fade?: boolean;
    focus?: boolean;
}
export interface PreloadOptions {
    assetPath: string;
    assetId: string;
    volume?: number;
    audioChannelNum?: number;
    isUrl?: boolean;
}
export interface QueueTrack {
    id: string;
    url: string;
    name: string;
    isMusic: boolean;
}
