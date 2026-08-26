#!/usr/bin/env bash
# Watches the live matchmaking tables while somebody plays.
#
# The browser cannot be driven from the development harness - a hidden page gets
# no animation frames, so Godot never ticks - but the *service* can be watched
# from anywhere. Somebody presses Host a room in a browser; this says whether the
# room arrived, whether a guest entered it, and whether they exchanged notes.
#
# That splits "web co-op does not work" into three distinct answers:
#   no room            -> the web build cannot reach the service
#   room, no guest     -> the guest never entered: wrong code, or enter_room failed
#   room + guest, no signals -> they met and never negotiated
#   signals, no join   -> negotiation happened and the channel never opened
set -u
K="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzY3lpb2FtcHZqZnFjY2ljY2llIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyNDI2NDksImV4cCI6MjEwMjgxODY0OX0.oN74ghnJqAlWtoRKWJVzb4Otw19lH68po_v2z2JlXmU"
B="https://xscyioampvjfqcciccie.supabase.co/rest/v1"
SECONDS_TO_WATCH="${1:-120}"

echo "watching for ${SECONDS_TO_WATCH}s - host a room in the browser now"
end=$((SECONDS + SECONDS_TO_WATCH))
last=""
while [ $SECONDS -lt $end ]; do
  lobbies="$(curl -s "$B/lobbies_public?select=code,players,locked" -H "apikey: $K" -H "Authorization: Bearer $K")"
  now="lobbies: $lobbies"
  if [ "$now" != "$last" ]; then
    printf '[%s] %s\n' "$(date +%H:%M:%S)" "$now"
    # players goes 1 -> 2 only when the host heartbeat reports a partner is
    # actually present, which is the far side of a completed handshake. It is
    # the one number that says the channel opened.
    if printf '%s' "$lobbies" | grep -q '"players":2'; then
      echo "    ^^ TWO PLAYERS - the channel opened. Web co-op works."
    fi
    last="$now"
  fi
  sleep 3
done
echo "done watching"
