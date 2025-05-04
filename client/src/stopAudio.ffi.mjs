export function do_stop_audio(audio) {
  console.log("Stopping audio");
  audio.pause();
  audio.currentTime = 0;
  audio.remove()
}