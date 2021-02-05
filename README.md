# VideoCutter

This cuts a video after a certain image (or something similiar to it) has been found in the video.

Needs:

> sudo cut.sh --install

For dependencies.

In every folder where multiple files are that need to be cut, there has to be a file called `cutimage.jpg`,
which is the file the video is compared to.

# How to run it

> bash cut.sh --dir=test --debug

This shows debug messages and removes the intros from the mp4 files in the folder "test".
