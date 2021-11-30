
# Table of Contents

1.  [jscreenshot - A utility for screenshotting and screen recording](#org134d662)
2.  [Installation:](#org2b8db8e)
3.  [Usage:](#org0321cb8)
4.  [Dependencies](#org259f8f2)
    1.  [Build](#orgab8c783)
    2.  [Run](#orge117bf2)
5.  [Future](#orgb5e4b95)
6.  [Credits](#orgbf8db69)


<a id="org134d662"></a>

# jscreenshot - A utility for screenshotting and screen recording

In an effort to avoid dealing with shell escaping, enable more complex
pipelines and user prompts, and to be able to generate an executable,
jscreenshot was born.


<a id="org2b8db8e"></a>

# Installation:

One can install this with `jpm install https://github.com/llmII/jscreenshot`


<a id="org0321cb8"></a>

# Usage:

Once one has installed this, there will be a binary named `screenshot` in
whichever directory they have `jpm` configured to install binaries. From there
usage is pretty much self representative, as when one launches the application
it will guide them through a series of steps to take a screenshot, take a
recording, or end a recording.


<a id="org259f8f2"></a>

# Dependencies


<a id="orgab8c783"></a>

## Build

-   jumble
-   spawn-utils
-   jsys


<a id="orge117bf2"></a>

## Run

-   grim
-   slurp
-   wf-recorder
-   swaymsg
-   pgrep
-   pkill


<a id="orgb5e4b95"></a>

# Future

This works great as is, but only if one runs wayland, and sway. We are not
averse to the extension of this to support x11, or other window
managers/compositors. It definitely would be nice for this to support more
selection tools (like rofi) or drop some dependencies on external
applications. This should also be improved to create the underlying
directories in which it will store images/videos. It&rsquo;d be nice for this to
separate dependencies into a &ldquo;recording&rdquo; and &ldquo;screenshotting&rdquo; subsets and be
capable of running with reduced functionality in the event we are missing a
set of dependencies as well.


<a id="orgbf8db69"></a>

# Credits

bakpakin - janet
sogaiu - discussion, code improvements

