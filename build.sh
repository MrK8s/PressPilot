#!/bin/bash

# Check if Go is installed
if ! [ -x "$(command -v go)" ]; then
  echo 'Error: Go is not installed.' >&2
  exit 1
fi

# Build the Go project
go build -o presspilot main.go

sudo mv presspilot /usr/local/bin

echo "Build complete. You can run the program with presspilot."