.PHONY: gen build run test e2e e2e-live e2e-lint clean
gen build run test e2e e2e-live e2e-lint clean:
	@$(MAKE) -C apps/mac $@ ONLY="$(ONLY)"
