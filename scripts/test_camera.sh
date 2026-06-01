#!/bin/bash

echo "Testing Pi Camera..."

rpicam-still -o test.jpg

if [ -f test.jpg ]; then
    echo "Success: test.jpg created"
else
    echo "Failed: image not captured"
fi