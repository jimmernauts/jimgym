import { Ok, Error as GError } from "./gleam.mjs"

export function do_stop_audio(audio) {
  console.log("Stopping audio");
  audio.pause();
  audio.currentTime = 0;
  audio.remove()
}

export async function requestWakeLock() {
  try {
    return new Ok(await window.navigator.wakeLock.request("screen"));
  } catch (error) {
    return new GError(error.toString());
  }
}

export async function releaseWakeLock(sentinel) {
  console.log("Releasing wake lock");
  sentinel.release();
}

export function every(interval, cb) {
  window.setTimeout(cb, interval);
}