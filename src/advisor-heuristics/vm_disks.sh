HEURISTIC_NAME="Virtual Machine Disks"
HEURISTIC_DESCRIPTION="Parallels, VMware, UTM, VirtualBox VM disk images."

discover() {
  for path_pattern in \
    "$HOME/Parallels/*.pvm" \
    "$HOME/Virtual Machines.localized/*.vmwarevm" \
    "$HOME/Virtual Machines.localized/*.vbox" \
    "$HOME/Library/Containers/com.utmapp.UTM/Data/Documents"/*.utm \
    "$HOME/VirtualBox VMs"/*; do
    for vm in $path_pattern; do
      [[ -e "$vm" ]] || continue
      b=$(path_bytes "$vm")
      [[ "$b" -lt 1073741824 ]] && continue
      days=$(( ( $(date +%s) - $(stat -f '%m' "$vm" 2>/dev/null || echo 0) ) / 86400 ))
      rec="Review"
      [[ $days -gt 180 ]] && rec="Safe (6m+ unused)"
      [[ $days -lt 30 ]] && rec="Keep (recently used)"
      la=$(stat -f '%Sm' -t '%Y-%m-%d' "$vm" 2>/dev/null || echo unknown)
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "VM: $(basename "$vm")" "$vm" "$b" "$la" "$rec" "Virtual machine. Cannot be regenerated; keep if you might need it."
    done
  done
}
