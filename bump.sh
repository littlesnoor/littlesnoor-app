#!/bin/sh
# Pakai: ./bump.sh "catatan 1" "catatan 2" ...   -> naikkan versi app, sw, version.json
set -e
cd "$(dirname "$0")"
V=$(python3 -c "import json;print(json.load(open('version.json'))['v']+1)")
sed -i "s/const APP_VERSION=[0-9]*;/const APP_VERSION=$V;/" index.html
sed -i "s/littlesnoor-v[0-9]*/littlesnoor-v$V/" sw.js
python3 - "$V" "$@" <<'PY'
import json,sys
v=int(sys.argv[1]); notes=sys.argv[2:]
json.dump({"v":v,"notes":notes},open("version.json","w"),ensure_ascii=False,indent=1)
PY
echo "versi $V"
