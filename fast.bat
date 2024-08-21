@echo off
zig build -Doptimize=ReleaseFast
rmdir .zig-cache /s /q