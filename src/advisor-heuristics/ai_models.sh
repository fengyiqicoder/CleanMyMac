HEURISTIC_NAME="Local AI Models"
HEURISTIC_DESCRIPTION="Downloaded LLM weights from Ollama, HuggingFace, LM Studio, llama.cpp."

discover() {
  # Ollama (~/.ollama/models)
  if [[ -d "$HOME/.ollama/models" ]]; then
    for blob_dir in "$HOME/.ollama/models/blobs" "$HOME/.ollama/models/manifests"; do
      [[ -d "$blob_dir" ]] || continue
      b=$(path_bytes "$blob_dir")
      [[ "$b" -lt 1073741824 ]] && continue
      days=$(( ( $(date +%s) - $(stat -f '%m' "$blob_dir" 2>/dev/null || echo 0) ) / 86400 ))
      rec="Review"
      [[ $days -gt 90 && $b -gt 5368709120 ]] && rec="Safe (large + 90d+ unused)"
      [[ $days -lt 30 ]] && rec="Keep (recently used)"
      la=$(stat -f '%Sm' -t '%Y-%m-%d' "$blob_dir" 2>/dev/null || echo unknown)
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "Ollama: $(basename "$blob_dir")" "$blob_dir" "$b" "$la" "$rec" "Local LLM data. Re-pull with: ollama pull <model>"
    done
  fi
  # HuggingFace
  if [[ -d "$HOME/.cache/huggingface/hub" ]]; then
    for model_dir in "$HOME/.cache/huggingface/hub"/models--*; do
      [[ -d "$model_dir" ]] || continue
      b=$(path_bytes "$model_dir")
      [[ "$b" -lt 1073741824 ]] && continue
      days=$(( ( $(date +%s) - $(stat -f '%m' "$model_dir" 2>/dev/null || echo 0) ) / 86400 ))
      rec="Review"
      [[ $days -gt 90 && $b -gt 5368709120 ]] && rec="Safe (large + 90d+ unused)"
      [[ $days -lt 30 ]] && rec="Keep (recently used)"
      la=$(stat -f '%Sm' -t '%Y-%m-%d' "$model_dir" 2>/dev/null || echo unknown)
      name=$(basename "$model_dir" | sed 's/^models--//; s/--/\//')
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "HuggingFace: $name" "$model_dir" "$b" "$la" "$rec" "Re-download via huggingface-cli or transformers."
    done
  fi
  # LM Studio
  if [[ -d "$HOME/.cache/lm-studio/models" ]]; then
    for model_dir in "$HOME/.cache/lm-studio/models"/*/*; do
      [[ -d "$model_dir" ]] || continue
      b=$(path_bytes "$model_dir")
      [[ "$b" -lt 1073741824 ]] && continue
      days=$(( ( $(date +%s) - $(stat -f '%m' "$model_dir" 2>/dev/null || echo 0) ) / 86400 ))
      rec=$([[ $days -gt 90 ]] && echo "Safe (90d+ unused)" || echo "Review")
      la=$(stat -f '%Sm' -t '%Y-%m-%d' "$model_dir" 2>/dev/null || echo unknown)
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "LM Studio: $(basename "$(dirname "$model_dir")")/$(basename "$model_dir")" "$model_dir" "$b" "$la" "$rec" "Re-download from LM Studio UI."
    done
  fi
}
