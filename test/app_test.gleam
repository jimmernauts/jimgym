import startest.{describe, it}
import startest/expect

pub fn main() {
  // Call `startest.run` inside of your `main` function.
  // Here we're using the default config, but you can customize this, as needed.
  startest.run(startest.default_config())
}
