@echo off
set MODEL=C:\models\gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf
set MTP_MODEL=C:\models\mtp-gemma-4-26B-A4B-it.gguf
set NGL=999
set CTX=65536

C:\llama-b9601\llama-server.exe ^
    -m "%MODEL%" ^
    --model-draft "%MTP_MODEL%" ^
    --spec-type draft-mtp ^
    --spec-draft-n-max 2 ^
    --host 0.0.0.0 ^
    --port 8080 ^
    --ctx-size %CTX% ^
    --batch-size 1024 ^
    --ubatch-size 512 ^
    --parallel 1 ^
    --flash-attn on ^
    --jinja ^
    --cache-type-k q4_0 ^
    --cache-type-v q4_0 ^
    --no-warmup ^
    --reasoning off ^
    -ngl %NGL% --fit on

pause