.PHONY: test smoke

test:
	nvim --headless -u tests/minimal_init.lua -l tests/run.lua

smoke:
	nvim --headless -u NONE -l tests/smoke.lua
