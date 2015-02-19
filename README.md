# MPEGDASH-iOS-Player
The MPEG-DASH Player iOS Application

This player is intended to play video that is transferred by MPEG-DASH protocol on iOS devices.
Player reads MPD-file, parses it and then downloads and plays media that MPD-file points to.
For video chunks decoding ffmpeg library is used.
With a reason to increase performance OpenGL ES was used. OpenGL ES does conversion from YUV to RGB color space using GPU.

Player supports two MPD-type: static and dynamic.
To use this app, you have to specify an MPD-file URL, and after player downloads it, press "Play" button.
If static stream is player, it is possible to scroll video to desired time position.
