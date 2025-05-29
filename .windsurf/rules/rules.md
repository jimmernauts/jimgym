---
trigger: always_on
---

* Use `just run` to run the app in dev mode
* `just run` will watch for changes and recompile, no need to restart it each time unless it dies
* Ignore linting errors in any directory other than `src`
* Do not use the string_builder module
* Always read the documentation for a gleam module on hexdocs.pm/<module_name> before trying to use it
* Do not attempt to use a function if you have not confirmed by looking at the module's docs that it exists 
* when writing code in Gleam, remember:
  * Use the <> operator to concatenate strings, not ++ or &&