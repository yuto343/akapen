.PHONY: gen build run test e2e e2e-live e2e-lint clean
gen:
	@xcodegen generate
build: gen
	@bash scripts/xcode.sh build
run: build
	@open build/DerivedData/Build/Products/Debug/akapen.app
test:
	@swift test --package-path Packages/AkapenKit
e2e:
	@python3 scripts/e2e.py fixture "$(ONLY)"
e2e-live:
	@python3 scripts/e2e.py live "$(ONLY)"
e2e-lint:
	@node e2e/check-specs.mjs
clean:
	@rm -rf build Packages/AkapenKit/.build
