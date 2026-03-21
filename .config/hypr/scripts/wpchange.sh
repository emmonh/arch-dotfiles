#!/bin/bash

rofi -filebrowser-cancel-returns-1 true -filebrowser-directory ~/wallpapers/ -filebrowser-command "awww img --transition-type center --transition-pos 0,0 --transition-step 90" -show filebrowser
