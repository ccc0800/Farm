@echo off
set MODEL=C:\models\gemma-4-31B-it-uncensored.gguf
set MMPROJ=C:\models\gemma-4-31B-it-mmproj-BF16.gguf
set NGL=999
set CTX=65536

C:\llama-b9827\llama-server.exe ^
    -m "%MODEL%" ^
    --mmproj "%MMPROJ%" ^
    --host 0.0.0.0 ^
    --port 8080 ^
    --ctx-size %CTX% ^
    --batch-size 1024 ^
    --ubatch-size 256 ^
    --parallel 1 ^
    --flash-attn on ^
    --jinja ^
    --cache-type-k q4_0 ^
    --cache-type-v q4_0 ^
    --no-warmup ^
    --reasoning off ^
    -ngl %NGL%

pause
