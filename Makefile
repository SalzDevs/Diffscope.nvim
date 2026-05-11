.PHONY: test

test:
	nvim --headless -u NONE -l tests/smoke.lua
