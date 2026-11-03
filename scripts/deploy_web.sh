#!/bin/sh
# Builds the web app and serves it from the homelab box on its Tailscale
# address only: http://100.105.90.110:8001/ (open it in Safari on the
# iPhone, then Share -> Add to Home Screen).
# An nginx container ("nyx-web") serves the files and proxies orc's
# /api, /assets and /t from port 8086 on the same box.
# Asks for the server password.
set -e
HOST=${NYX_HOST:-debian@100.105.90.110}
DIR=apps/nyx-web
cd "$(dirname "$0")/.."
flutter build web --release --no-web-resources-cdn
rm -rf build/web-deploy && mkdir -p build/web-deploy
cp -r build/web build/web-deploy/site && cp deploy/web/nginx.conf build/web-deploy/
tar -czf - -C build/web-deploy . |
  ssh "$HOST" "set -e
    rm -rf $DIR.new && mkdir -p $DIR.new && tar -xzf - -C $DIR.new
    rm -rf $DIR && mv $DIR.new $DIR && mkdir -p apps/nyx-library
    docker rm -f nyx-web >/dev/null 2>&1 || true
    docker run -d --name nyx-web --restart unless-stopped \
      -p 100.105.90.110:8001:80 --add-host host.docker.internal:host-gateway \
      -v \$HOME/$DIR/site:/usr/share/nginx/html:ro \
      -v \$HOME/$DIR/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
      -v \$HOME/apps/nyx-library:/srv/library:ro \
      nginx:alpine >/dev/null"
echo "Website deployed: http://${HOST#*@}:8001/"
