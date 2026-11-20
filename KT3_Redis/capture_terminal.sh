#!/usr/bin/env bash
set -euo pipefail

stage=start
report_error() {
  status=$?
  cluster_log="$(tail -c 1200 /tmp/kt3_console.log 2>/dev/null | tr '\n' '|' || true)"
  display_log="$(tail -c 400 /tmp/kt3_xvfb.log 2>/dev/null | tr '\n' '|' || true)"
  xterm_log="$(tail -c 400 /tmp/kt3_xterm.log 2>/dev/null | tr '\n' '|' || true)"
  printf '::error title=KT3 terminal capture::status=%s stage=%s console=%s display=%s xterm=%s\n' "$status" "$stage" "$cluster_log" "$display_log" "$xterm_log"
}
trap report_error ERR

export DISPLAY=:99
export KT3_CAPTURE_DIR=/tmp/kt3_capture
mkdir -p "$KT3_CAPTURE_DIR" KT3_Redis/screenshots
Xvfb :99 -screen 0 1600x900x24 >/tmp/kt3_xvfb.log 2>&1 &
sleep 1

xterm -T 'KT3_1 Redis Cluster - GitHub Actions terminal' \
  -geometry 150x45+20+20 -fa 'DejaVu Sans Mono' -fs 12 \
  -bg '#1e1e1e' -fg '#e8e8e8' -hold \
  -e bash -lc 'echo "$ python3 KT3_Redis/failover.py"; python3 -u KT3_Redis/failover.py 2>&1 | tee /tmp/kt3_console.log; echo "${PIPESTATUS[0]}" > /tmp/kt3_exit' \
  2>/tmp/kt3_xterm.log &

for stage in before written failed recovered; do
  timeout 90 bash -c 'until test -f "$1/$2.ready"; do sleep 0.2; done' _ "$KT3_CAPTURE_DIR" "$stage"
  scrot "KT3_Redis/screenshots/$(case "$stage" in before) echo 05_кластер_терминал;; written) echo 06_запись_терминал;; failed) echo 07_сбой_терминал;; recovered) echo 08_восстановление_терминал;; esac).png"
  touch "$KT3_CAPTURE_DIR/$stage.continue"
done

timeout 90 bash -c 'until test -f /tmp/kt3_exit; do sleep 0.2; done'
test "$(cat /tmp/kt3_exit)" = 0
test "$(find KT3_Redis/screenshots -name '0[5-8]_*.png' | wc -l)" = 4

