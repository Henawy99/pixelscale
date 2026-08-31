#!/bin/bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9223 \
  --user-data-dir="$(pwd)/foodora-profile" \
  "https://partner.foodora.com/orders"
