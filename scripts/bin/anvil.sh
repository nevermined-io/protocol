#!/bin/bash

# Name of the application binary or command
APP_NAME="anvil"

# Command to start the application (full path or command if in $PATH)
START_CMD="anvil > /dev/null &"

# Check if the application is running
if ! pgrep -x "$APP_NAME" > /dev/null
then
    echo "$APP_NAME is not running. Starting it now..."
    eval $START_CMD
else
    echo "$APP_NAME is already running."
fi