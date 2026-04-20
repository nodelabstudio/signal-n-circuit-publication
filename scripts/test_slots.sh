#!/bin/bash
slot_time_et() {
  case "$1" in
    1) echo "8:00 AM ET" ;;
    2) echo "11:00 AM ET" ;;
    3) echo "4:00 PM ET" ;;
    4) echo "7:00 PM ET" ;;
    5) echo "9:00 PM ET" ;;
    6) echo "11:00 PM ET" ;;
  esac
}
for slot in 1 2 3 4 5 6; do
  echo "Slot $slot: $(slot_time_et $slot)"
done
