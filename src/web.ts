import { WebPlugin } from '@capacitor/core';

import { AudioAsset } from './audio-asset';
import type {
  ConfigureOptions,
  PreloadOptions, QueueTrack
} from './definitions';
import { NativeAudio } from './definitions';

export class NativeAudioWeb extends WebPlugin implements NativeAudio {
  private static readonly FILE_LOCATION: string = 'assets/sounds';
  private static readonly AUDIO_ASSET_BY_ASSET_ID: Map<string, AudioAsset> = new Map<string, AudioAsset>();

  constructor() {
    super({
      name: 'NativeAudio',
      platforms: ['web'],
    });
  }

  getQueuePlayingIndex(options: { id: string; }): Promise<number> {
    options.id
        throw new Error('Method not implemented.');
    }

  async resume(options: { assetId: string; }): Promise<void> {
    const audio: HTMLAudioElement = this.getAudioAsset(options.assetId).audio;
    if (audio.paused) {
      return audio.play();
    }
  }

  async pause(options: { assetId: string; }): Promise<void> {
    const audio: HTMLAudioElement = this.getAudioAsset(options.assetId).audio;
    return audio.pause();
  }

  async getCurrentTime(options: { assetId: string }): Promise<{ currentTime: number; }> {
    const audio: HTMLAudioElement = this.getAudioAsset(options.assetId).audio;
    return { currentTime: audio.currentTime };
  }

  async getDuration(options: { assetId: string; }): Promise<{ duration: number; }> {
    const audio: HTMLAudioElement = this.getAudioAsset(options.assetId).audio;
    if (Number.isNaN(audio.duration)) {
      throw 'no duration available';
    }
    if (!Number.isFinite(audio.duration)) {
      throw 'duration not available => media resource is streaming';
    }
    return { duration: audio.duration };
  }

  async configure(options: ConfigureOptions): Promise<void> {
    throw `configure is not supported for web: ${JSON.stringify(options)}`;
  }

  async preload(options: PreloadOptions): Promise<void> {
    if (NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID.has(options.assetId)) {
      throw 'AssetId already exists. Unload first if like to change!';
    }
    if (!options.assetPath?.length) {
      throw 'no assetPath provided';
    }
    if (!options.isUrl && !new RegExp('^/?' + NativeAudioWeb.FILE_LOCATION).test(options.assetPath)) {
      const slashPrefix: string = options.assetPath.startsWith('/') ? '' : '/';
      options.assetPath = `${NativeAudioWeb.FILE_LOCATION}${slashPrefix}${options.assetPath}`;
    }
    const audio: HTMLAudioElement = new Audio(options.assetPath);
    audio.autoplay = false;
    audio.loop = false;
    audio.preload = 'auto';
    if (options.volume) {
      audio.volume = options.volume;
    }
    NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID.set(options.assetId, new AudioAsset(audio));
  }

  async play(options: { assetId: string, time?: number }): Promise<void> {
    const audio: HTMLAudioElement = this.getAudioAsset(options.assetId).audio;
    await this.stop(options);
    audio.loop = false;
    audio.currentTime = options.time ?? 0;
    return audio.play();
  }

  async loop(options: { assetId: string }): Promise<void> {
    const audio: HTMLAudioElement = this.getAudioAsset(options.assetId).audio;
    await this.stop(options);
    audio.loop = true;
    return audio.play();
  }

  async stop(options: { assetId: string }): Promise<void> {
    const audio: HTMLAudioElement = this.getAudioAsset(options.assetId).audio;
    audio.pause();
    audio.loop = false;
    audio.currentTime = 0;
  }

  async unload(options: { assetId: string }): Promise<void> {
    await this.stop(options);
    NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID.delete(options.assetId);
  }

  async setVolume(options: { assetId: string, volume: number }): Promise<void> {
    if (typeof options?.volume !== 'number') {
      throw 'no volume provided';
    }

    const audio: HTMLAudioElement = this.getAudioAsset(options.assetId).audio;
    audio.volume = options.volume;
  }

  async isPlaying(options: { assetId: string }): Promise<{ isPlaying: boolean; }> {
    const audio: HTMLAudioElement = this.getAudioAsset(options.assetId).audio;
    return { isPlaying: !audio.paused };
  }


  private getAudioAsset(assetId: string): AudioAsset {
    this.checkAssetId(assetId);

    if (!NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID.has(assetId)) {
      throw `no asset for assetId "${assetId}" available. Call preload first!`;
    }

    return NativeAudioWeb.AUDIO_ASSET_BY_ASSET_ID.get(assetId) as AudioAsset;
  }

  private checkAssetId(assetId: string): void {
    if (typeof assetId !== 'string') {
      throw 'assetId must be a string';
    }

    if (!assetId?.length) {
      throw 'no assetId provided';
    }
  }

  cancelSleepTimer(): Promise<void> {
    return Promise.resolve(undefined);
  }

  getCurrentQueueIndex(): Promise<number> {
    return Promise.resolve(0);
  }

  getQueueTrackCurrentTime(id: string): Promise<number> {
    console.log(id)
    return Promise.resolve(0);
  }

  isQueuePaused(options: { id: string }): Promise<{ isQueuePaused: boolean }> {
    options.id
    return Promise.resolve({isQueuePaused: false});
  }

  isQueuePlaying(options: { id: string }): Promise<{ isQueuePlaying: boolean }> {
    options.id
    return Promise.resolve({isQueuePlaying: false});
  }

  pauseQueue(options: { id: string }): Promise<void> {
    options.id
    return Promise.resolve(undefined);
  }

  playNextQueueTrack(id: string): Promise<void> {
    console.log(id)
    return Promise.resolve(undefined);
  }

  playPreviousQueueTrack(id: string): Promise<void> {
    console.log(id)
    return Promise.resolve(undefined);
  }

  // @ts-ignore
  playQueue(options: { id: string; tracks: QueueTrack[]; startIndex: number; startTime: number; trailingTime: number; timerUpdateInterval: number; volume: number; useFade: boolean; loop: boolean }): Promise<void> {
    options.id
    return Promise.resolve(undefined);
  }

  queueHasTrackWith(options: { id: string; url: string }): Promise<{ has: boolean }> {
    options.id
    return Promise.resolve({has: false});
  }

  resumeQueue(options: { id: string }): Promise<void> {
    options.id
    return Promise.resolve(undefined);
  }

  seekQueue(options: { id: string; time: number }): Promise<void> {
    options.id
    return Promise.resolve(undefined);
  }

  setQueueLoopIndex(options: { id: string; index: number; set: boolean }): Promise<number> {
    options.id
    return Promise.resolve(0);
  }

  setQueueVolume(options: { id: string; volume: number }): Promise<void> {
    options.id
    return Promise.resolve(undefined);
  }

  setSleepTimer(options: { time: number }): Promise<void> {
    options.time
    return Promise.resolve(undefined);
  }

  unloadQueue(options: { id: string }): Promise<void> {
    options.id
    return Promise.resolve(undefined);
  }

  requestNotificationPermission(options: { mode: number, text: string, positiveText: string, negativeText: string} ): Promise<{ acquired: boolean }> {
    options.text
    return Promise.resolve({ acquired: false });
  }
}

const NativeAudio = new NativeAudioWeb();

export { NativeAudio };

