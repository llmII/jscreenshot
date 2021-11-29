# subprocess handling --------------------------------------------------------
# NOTE: The application using `pipe` or `process-spawn` becomes the buffer
# inbetween each process. While not ideal, if such were not done then pipe
# would have to attach the output of a process to the input of another without
# determining if a process ran successfully. The reason is that as a process
# produces output, it will fill the pipe, up to the operating system's buffer
# limit for pipes. At that point the process blocks until the pipe's buffer is
# emptied. A process's output, when redirected into a pipe simply bust have
# something that consumes it while it is being produced.
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

(comment

  (pipe nil [["echo" "hello"] ["cat"]]) # -> "hello\n"
  (pipe "hello" [["cat"]]) # -> "hello\n"
  (pipe (pipe [["echo" "hello"]]) [["cat"]]) # -> "hello\n"
  # TODO:
  (pipe [(fn [] (pipe [["echo" "hello"]])) ["cat"]]) # -> "hello\n"

  )

(defn- plumb [data junction]
  (if (function? junction)
    (junction data)
    (process-spawn data junction)))

(defn pipe [& plumbing]
  (let [return-type (when (keyword? (last plumbing)) (array/pop plumbing))
        tail        (when (bytes? (first plumbing))
                      {:out (array/remove plumbing 0)})
        state       @{:tail  (or tail {})
                      :stack @[]}]
    (each junction plumbing
      (put state :tail (plumb ((state :tail) :out) junction))
      (array/push stack (state :tail)))
    (match output
      :full state
      :last (state :tail)
      _ ((state :tail) :out))))
