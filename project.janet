(declare-project
  :name "jscreenshot"
  :author "llmII <dev@amlegion.org>"
  :licesne "OWL"
  :url "https://github.com/llmII/jscreenshot"
  :repo "git+https://github.com/llmII/jscreenshot.git"
  :dependencies ["https://github.com/llmII/jsys" # for date-string
                 "https://github.com/llmII/jumble" # for check-in-path
                 "https://github.com/llmII/spawn-utils"] # for pipe
  :description
  ```
  A utility for screenshotting and screen recording.
  ```)

(declare-executable
  :name "screenshot"
  :entry "jscreenshot.janet"
  :install true)
