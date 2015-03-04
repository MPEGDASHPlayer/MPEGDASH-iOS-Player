# MPEGDASH-iOS-Player

[DataArt]: http://dataart.com "DataArt"

The MPEG-DASH Player iOS Application
------------------

This player is designed to play a video that is transferred by the MPEG-DASH protocol to iOS devices.
The player reads a MPD-file, parses it, and then downloads and plays the media that MPD-file points to.
 
The ffmpeg library is used for decoding video chunks.
OpenGL ES is used to increase performance. OpenGL ES does conversion from YUV to RGB color space using the GPU.
The player supports two MPD-types: static and dynamic.
 
To use this app, you need to specify an MPD-file URL, and after the player has downloaded it, you press the "Play" button.
If a static stream is played, it is possible to scroll the video to any desired time position.

License
------------------

MPEG-DASH Player iOS Application is developed by [DataArt] Apps and distributed under Open Source
[MIT license](http://en.wikipedia.org/wiki/MIT_License).

© Copyright 2015 DataArt Apps. All Rights Reserved
