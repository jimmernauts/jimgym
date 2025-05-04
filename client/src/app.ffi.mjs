// app.ffi.mjs
export function every(interval, cb) {
  window.setTimeout(cb, interval);
}