#!/bin/bash
set -e

# Đọc biến từ file .env
declare -A env_vars
while IFS='=' read -r key value; do
  if [[ -n "$key" ]]; then
    env_vars[$key]=$value
  fi
done < .env

# Tạo bản sao của template
cp android/app/google-services.json.template android/app/google-services.json
cp android/app/src/main/AndroidManifest.xml.template android/app/src/main/AndroidManifest.xml

# Thay thế biến trong google-services.json
for key in "${!env_vars[@]}"; do
  sed -i "s|\${$key}|${env_vars[$key]}|g" android/app/google-services.json
done

# Thay thế biến trong AndroidManifest.xml
for key in "${!env_vars[@]}"; do
  sed -i "s|\${$key}|${env_vars[$key]}|g" android/app/src/main/AndroidManifest.xml
done

echo "Đã sinh file google-services.json và AndroidManifest.xml từ template!"