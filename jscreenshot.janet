# -------------------------------------------------------------------------- #
# Copyright (c) 2021 - llmII <dev@amlegion.org>D
# License: Open Works License v0.9.4 (LICENSE.md)
#
# jscreenshot
#
#   This is a tool to help in the creation of screenshots or screen recordings
#   under wayland. Particularly it is designed for sway and is dependent upon
#   slurp, grim, wf-recorder, and swaymsg. It can also, optionally, do OCR
#   with tesseract.
#
#   This also needs a wofi like utility that it can launch to provide a
#   selection interface.

(import json)
(use sys)
# collect environment variables
(def env
  @{:path     (string/split ":" (os/getenv "PATH"))
    :pictures (string (os/getenv "XDG_PICTURES_DIR" "Pictures")
                      "/screenshots")
    :videos   (string (os/getenv "XDG_VIDEOS_DIR" "Videos")
                      "/screen-recordings")
    :wofi     (string (os/getenv "VISUAL_SELECTION_TOOL" "wofi"))
    :tessdata (string (os/getenv "TESSDATA_PREFIX"
                                 "/usr/local/share/tessdata"))})

# subprocess handling --------------------------------------------------------
(defn process-spawn [previous junction]
  (let [spawn-opts {:in (when previous :pipe) :out :pipe :err :pipe}
        ret @{}]
    (pp junction)
    (with [proc (os/spawn junction :px spawn-opts)]
      (try
        (do
          # Ensure you read and write pipe simutaneously, don't end up
          # hung because a pipe is stuck with a full buffer
          (ev/gather
            (when previous
              (:write (proc :in) previous)
              (:close (proc :in)))
            (put ret :out (:read (proc :out) :all))
            (put ret :err (:read (proc :err) :all)))
          (put ret :exit-code (:wait proc)))
        ([err]
          (errorf (string "Error <%V>: running `%s` with args [\"%s\"]\n\t"
                          "Spawned process stderr:\n\t\t%v")
                  err
                  (get junction 0)
                  (string/join (array/slice junction 1 -1) `" "`)
                  (ret :err)))))
    ret))

(defn pipe [input plumbing &opt output]
  (let [state @{:stack @[]}]
    (each junction plumbing
      (let [tail (or (state :tail) {:out input})]
        (match (type junction)
          :function (put state :tail (junction (tail :out)))
          (x (or (= x :tuple) (= x :array)))
          (put state :tail (process-spawn (tail :out) junction))))
      (array/push (state :stack) (state :tail)))
    (match output
      :full state
      :last (state :tail)
      _ ((state :tail) :out))))

# dependency checking --------------------------------------------------------

# we need arity 2 or/and functions
(defn and2 [a b]
  (and a b))

(defn or2 [a b]
  (or a b))

# code courtesy of @sogaiu from github
(defn check-programs-exist [program-type & files]
  (when (pos? (length files))
    (->> files
         (map
           (fn [file]
             (let [result (reduce2
                            or2
                            (map (fn [path]
                                   (os/stat (string path "/" file)))
                                 (env :path)))]
               (printf "%s %s %s in $PATH." program-type file
                       (if result "exists" "does not exist"))
               result)))
         (reduce2 and2))))

# Begin program --------------------------------------------------------------
(defn wofi [prompt]
  ["wofi" "-dImi" "-L9" "-w2" "-W600" "-H600" "-p" prompt])

# check for dependencies
(when
  (not
    (check-programs-exist
      "Dependency"
      ;["grim" "slurp" "wf-recorder" "swaymsg" "pgrep" "pkill" (env :wofi)]))
  (eprint "Some dependencies were missing.\n"
       "Please install the required dependencies and try again.\n")
  (os/exit 1))

(put env :have-tesseract
     (check-programs-exist "Optional dependency" "tesseract"))

(defn prompt [msg options]
  (try
    (options
      (string/trim
        (pipe
          (string/join (keys options) "\n")
          [(wofi (string msg))])
        "\n"))
    ([err]
      (eprintf "Option selection failure.\n%s\n" err)
      (os/exit 2))))

(defn check-tree [k v ret]
  (when (and (or (indexed? v) (dictionary? v)) (not= k "rect"))
    (when (and (dictionary? v)
               (or (and (v "visible") (v "pid")) (= (v "type") "output")))
      (array/push
        ret
        (string/format "%d,%d %dx%d"
                       ((v "rect") "x")
                       ((v "rect") "y")
                       ((v "rect") "width")
                       ((v "rect") "height"))))
    true))

(defn filter-tree-impl [decoded ret]
  (eachp [k v] decoded
    (when (check-tree k v ret)
      (filter-tree-impl v ret))))

(defn filter-tree [json]
  (let [decoded (json/decode json)
        ret @[]]
    (filter-tree-impl decoded ret)
    (string/join ret "\n")))

# how to use slurp and have it select windows or screens
# swaymsg -t get_tree |
#   jq -r '.. | select((.pid? and .visible?) or .type == "output") | .rect | "\(.x),\(.y) \(.width)x\(.height)"'
(defn select-rect [recording-type]
  (match (prompt (string/format "Select area to %s" recording-type)
           {"Window/Screen" [:selection false]
            "Area"          [:selection true]
            "All screens"   :all})
    [:selection ocr]
    (try
      [(string/trim
         (pipe
           (filter-tree (pipe nil [["swaymsg" "-rt" "get_tree"]]))
           [["slurp" (if ocr "-o" "-or")]]) "\n")
       (and ocr (env :have-tesseract))]
      ([err]
        (eprintf "Area selection failure.\n%s\n" err)
        (os/exit 4)))))

(defn select-file [file-type]
  (try
    (do
      (string
        (env (match file-type :screenshot :pictures :recording :videos))
        "/"
        (string/trim
          (pipe
            (date-string
              (os/date)
              (string/format "%s-%s.%s" (string file-type) "%F_%T"
                             (match file-type
                               :screenshot "png"
                               :recording "mp4")))
            [(wofi
               (string/format "Select a file name for you %s:"
                              (string file-type)))]))
        "\n"))
    ([err]
      (eprintf "File name selection failure.\n%s\n" err)
      (os/exit 3))))

(defn select-destination [&keys {:file file-type
                                 :clipboard clipboard
                                 :ocr ocr}]
  (let [options            @{(string/format
                               "Save %s to file?" (string file-type)) :file}
        destination-prompt (string/format
                             "Where would you like to send %s to?"
                             (string file-type))]
    (when clipboard
      (put options (string/format "Copy %s to clipboard" (string file-type))
           :clipboard))
    (when ocr
      (put options (string/format "Run %s through ocr?" (string file-type))
           :ocr))
    (match (prompt destination-prompt options)
      :file
      [(select-file file-type)]
      :clipboard
      ["-" [["wl-copy"]]]
      :ocr
      ["-" [["tesseract" "-" "-" "--tessdata-dir" (env :tessdata)]
            ["wl-copy" "-f"]]]
      _ [])))

(defn screenshot []
  (let [grim @["grim"]
        [rect ocr] (or (select-rect "screenshot") [])
        [destination post-processing] (select-destination
                                        :file :screenshot
                                        :clipboard true
                                        :ocr ocr)]
    (when rect (array/concat grim "-g" rect))
    (array/concat grim destination)
    (default post-processing [])
    (pipe nil [grim ;post-processing])))


# determine are we allowed to take or end recording
(let [options     @{"Take Screenshot" :screenshot}
      user-prompt @"Take Screenshot"]
  # with pgrep, errors are ok, we just want to determine if wf-recorder is
  # running and keep from showing options that aren't available during a
  # recording.
  (try
    (do
      (pipe nil [["pgrep" "wf-recorder"]])
      (buffer/push user-prompt " or End Recording")
      (put options "End recording" :end-recording))
    ([_]
      (buffer/push user-prompt " or Start Recording")
      (put options "Start Recording" :start-recording)))
  (match (prompt user-prompt options)
    :screenshot (screenshot)
    :start-recording
    :end-recording))