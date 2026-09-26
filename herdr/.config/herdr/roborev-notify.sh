#!/bin/sh
# Raise a herdr toast + "done" sound when a roborev review finishes,
# matching the alert herdr gives when an agent completes.
# Called from a roborev [[hooks]] entry: roborev-notify.sh {repo_name} {verdict}

repo=$1
case $2 in
  P) result="passed" ;;
  F) result="found issues" ;;
  *) result="finished" ;;
esac

exec /opt/homebrew/bin/herdr notification show "roborev: $repo" \
  --body "Review $result" --sound done
