# Run all test files
test: deps/mini.nvim deps/nui.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable
test_file: deps/mini.nvim deps/nui.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

# 'mini.nvim' provides the 'mini.test' testing module
deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-mini/mini.nvim $@

# 'nui.nvim' is a runtime dependency; tests mount the real UI
deps/nui.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/MunifTanjim/nui.nvim $@

.PHONY: test test_file
