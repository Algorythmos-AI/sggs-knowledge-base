# SGGS Knowledge Base — developer entrypoints. `make help` lists targets.
# PIPELINE_PY is the interpreter that has PyMuPDF/numpy/scipy (see CONTRIBUTING.md).
PIPELINE_PY ?= /usr/bin/python3
PDF ?= ../Siri-Guru-Granth-Sahib-in-Gurmukhi-with-Index.pdf

.PHONY: help doctor ci check-versions test-web test-frontend contract verify guard reconcile rebuild ios-db release testflight
help: ## list targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

doctor: ## check the local toolchain (the python3 trap, node, git-lfs, pdf)
	@echo "pipeline python: $(PIPELINE_PY)"; $(PIPELINE_PY) -c "import sys,fitz,numpy,scipy;print('  ok', sys.version.split()[0], '+ PyMuPDF/numpy/scipy')" || echo "  MISSING PyMuPDF/numpy/scipy — pick an interpreter that has them (PIPELINE_PY=...)"
	@command -v node >/dev/null && echo "node: $$(node -v)" || echo "  node missing"
	@command -v git-lfs >/dev/null && echo "git-lfs: ok" || echo "  git-lfs missing"
	@test -f db/sggs.sqlite && head -c 16 db/sggs.sqlite | grep -q "SQLite format 3" && echo "db: real SQLite" || echo "  db/sggs.sqlite missing or an LFS pointer — run: git lfs pull"
	@test -f "$(PDF)" && echo "pdf: present" || echo "  source PDF not at $(PDF) (needed only for reconcile/rebuild)"

check-versions: ## assert the version is unified across all 8 locations
	python3 scripts/release/check_versions.py

test-web: ## server unit tests
	python3 -m unittest discover -s webapp/tests -v

test-frontend: ## frontend build + pahar vectors
	cd frontend && npm ci && npm run build && npm run test:pahar

contract: ## regenerate golden vectors and fail if they drift
	python3 pipeline/gen_golden_vectors.py && git diff --exit-code contract/

verify: ## structural regroup invariants on the current DB
	python3 pipeline/verify_regroup.py --invariants db/sggs.sqlite

guard: ## pre-existing tables byte-identical to the committed baseline (+ bani registry invariants)
	python3 pipeline/timing/guard_scripture.py
	python3 pipeline/banis/guard_banis.py

banis: ## (re)build the Nitnem bani registry into db/sggs.sqlite (needs ./database.sqlite from ShabadOS)
	python3 pipeline/banis/build_banis.py --report docs/nitnem/review-pack/sggs-placements.json
	python3 pipeline/banis/guard_banis.py

test-banis: ## gate tests for the bani registry on a throwaway copy of the DB
	python3 pipeline/banis/test_banis_layer.py

ci: check-versions verify guard test-web contract ## run the gates CI runs (no PDF needed)
	@echo "make ci: PASS"

reconcile: ## prove corpus == PDF char-for-char and write the attestation (needs PDF)
	$(PIPELINE_PY) pipeline/reconcile.py "$(PDF)" corpus/sggs.jsonl
	$(PIPELINE_PY) pipeline/golden_test.py "$(PDF)" >/dev/null && echo "golden PASS"
	$(PIPELINE_PY) scripts/release/write_attestation.py "$(PDF)"

rebuild: ## full deterministic rebuild from the PDF (needs PIPELINE_PY with PyMuPDF/scipy)
	rm -rf corpus/by-raag/*
	PATH=$$(dirname $(PIPELINE_PY)):$$PATH bash pipeline/rebuild_all.sh "$(PDF)"

ios-db: ## rebuild both iOS SQLite profiles + license gate
	python3 pipeline/build_ios_db.py --profile personal
	python3 pipeline/build_ios_db.py --profile public
	bash pipeline/check_release_license.sh

release: ## bump the unified version everywhere: make release VERSION=1.2.0
	@test -n "$(VERSION)" || (echo "usage: make release VERSION=X.Y.Z"; exit 1)
	python3 scripts/release/bump.py $(VERSION)
	python3 scripts/release/check_versions.py

MARKETING_VERSION = $(shell python3 -c "import re;print(re.search(r'MARKETING_VERSION:\s*\"([^\"]+)\"',open('ios/App/project.yml').read()).group(1))")

testflight-next: ## the next TestFlight build number for the current marketing version
	@echo "version $(MARKETING_VERSION) — next build: $$(python3 ios/tools/testflight_ledger.py next $(MARKETING_VERSION))"

testflight: ## archive + gate + export/upload the TestFlight candidate (macOS): make testflight TEAM_ID=… BUILD=N [PROFILE=public] [UPLOAD=1]
	@test -n "$(TEAM_ID)" || { echo "usage: make testflight TEAM_ID=ABCDE12345 BUILD=N [PROFILE=public|personal] [UPLOAD=1]"; exit 1; }
	@test -n "$(BUILD)" || { echo "usage: make testflight TEAM_ID=ABCDE12345 BUILD=N [PROFILE=public|personal] [UPLOAD=1]"; \
		echo "version $(MARKETING_VERSION) — next build: $$(python3 ios/tools/testflight_ledger.py next $(MARKETING_VERSION))"; exit 1; }
	SGGS_TEAM_ID=$(TEAM_ID) SGGS_BUILD_NUMBER=$(BUILD) SGGS_DB_PROFILE=$(or $(PROFILE),public) SGGS_UPLOAD=$(or $(UPLOAD),0) bash ios/tools/testflight_archive.sh
