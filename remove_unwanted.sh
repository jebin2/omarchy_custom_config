#!/bin/bash

# Declare an array of webapp names
declare -a webapps=("HEY" "WhatsApp" "X" "YouTube" "Discord" "Basecamp" "Figma" "GitHub" "Google Contacts" "Google Messages" "Google Photos")

for app in "${webapps[@]}"
do
  omarchy-webapp-remove "$app"
done