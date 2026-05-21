HEURISTIC_NAME="Stale Python Environments"
HEURISTIC_DESCRIPTION="venv/.venv folders + conda envs not used in 90+ days."

discover() {
  # venv / .venv
  /usr/bin/find "$HOME" -maxdepth 5 \( -name venv -o -name .venv -o -name env \) -type d \
    -not -path "*/Library/*" -not -path "*/.Trash/*" \
    -prune 2>/dev/null | while IFS= read -r v; do
    [[ -f "$v/pyvenv.cfg" ]] || continue
    parent="$(dirname "$v")"
    days=$(( ( $(date +%s) - $(stat -f '%m' "$parent" 2>/dev/null || echo 0) ) / 86400 ))
    [[ $days -lt 90 ]] && continue
    b=$(path_bytes "$v")
    [[ "$b" -lt 10485760 ]] && continue  # < 10 MB
    la=$(stat -f '%Sm' -t '%Y-%m-%d' "$parent" 2>/dev/null || echo unknown)
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "Python env: $(basename "$parent")/$(basename "$v")" "$v" "$b" "$la" "Safe (90d+)" "Re-create with: python -m venv $(basename "$v") && pip install -r requirements.txt."
  done
  # Conda envs
  for conda_root in "$HOME/anaconda3/envs" "$HOME/miniconda3/envs" "$HOME/miniforge3/envs" "$HOME/mambaforge/envs"; do
    [[ -d "$conda_root" ]] || continue
    for env in "$conda_root"/*; do
      [[ -d "$env" ]] || continue
      days=$(( ( $(date +%s) - $(stat -f '%m' "$env" 2>/dev/null || echo 0) ) / 86400 ))
      [[ $days -lt 90 ]] && continue
      b=$(path_bytes "$env")
      la=$(stat -f '%Sm' -t '%Y-%m-%d' "$env" 2>/dev/null || echo unknown)
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "Conda env: $(basename "$env")" "$env" "$b" "$la" "Safe (90d+)" "Re-create with: conda create -n $(basename "$env") ..."
    done
  done
}
