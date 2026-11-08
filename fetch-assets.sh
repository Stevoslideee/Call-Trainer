#!/usr/bin/env bash
# Render build step: download the speech model and prospect voices so the site serves them itself.
# Never fails the deploy: anything that can't download falls back to the public copy in the app.
set -u
A=assets; mkdir -p "$A"
get(){ mkdir -p "$(dirname "$2")"; curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 -o "$2.part" "$1" && mv "$2.part" "$2"; }

HF=https://huggingface.co
ASR=onnx-community/moonshine-base-ONNX
asr_ok=true
for f in config.json generation_config.json preprocessor_config.json special_tokens_map.json tokenizer.json tokenizer_config.json \
         onnx/encoder_model_quantized.onnx onnx/decoder_model_merged_quantized.onnx; do
  get "$HF/$ASR/resolve/main/$f" "$A/models/$ASR/$f" || { echo "ASR file failed: $f"; asr_ok=false; }
done

voices=""
for v in dana:en/en_US/amy/medium/en_US-amy-medium.onnx priya:en/en_US/lessac/medium/en_US-lessac-medium.onnx \
         marcus:en/en_US/ryan/medium/en_US-ryan-medium.onnx tom:en/en_US/joe/medium/en_US-joe-medium.onnx \
         jordan:en/en_US/hfc_male/medium/en_US-hfc_male-medium.onnx rachel:en/en_US/kristin/medium/en_US-kristin-medium.onnx; do
  id=${v%%:*}; p=${v#*:}
  if get "$HF/diffusionstudio/piper-voices/resolve/main/$p.json" "$A/voices/$p.json" && get "$HF/diffusionstudio/piper-voices/resolve/main/$p" "$A/voices/$p"; then
    voices="$voices\"$id\":true,"
  else echo "Voice failed: $id"; fi
done

printf '{"asr":%s,"voices":{%s},"built":"%s"}\n' "$asr_ok" "${voices%,}" "$(date -u +%FT%TZ)" > "$A/manifest.json"
cat "$A/manifest.json"; du -sh "$A" || true
exit 0
