# SGGS Knowledge Base (platform: API + web) — developer entrypoints. `make help` lists targets.
# The scripture database is owned by Algorythmos-AI/sggs-data and consumed by pin (dataset.lock.json);
# data rebuilds, reconcile and the scripture gates live there.

.PHONY: help doctor dataset dataset-check ci openapi contract-http pr-checks release-preflight watch-deploy verify-prod check-versions test-web test-frontend contract harnesses canary slices release docs docs-dev docs-check docs-e2e posters
help: ## list targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

doctor: ## check the local toolchain and the installed database
	@python3 -c "import sys;print('python:', sys.version.split()[0])"
	@command -v node >/dev/null && echo "node: $$(node -v)" || echo "  node missing"
	@test -f db/sggs.sqlite && head -c 16 db/sggs.sqlite | grep -q "SQLite format 3" && echo "db: real SQLite" || echo "  db/sggs.sqlite missing — run: make dataset"
	@python3 scripts/data/fetch_dataset.py --check-repo

dataset: ## install db/sggs.sqlite from the pinned sggs-data object (dataset.lock.json), sha256-verified
	python3 scripts/data/fetch_dataset.py --cache-dir .dataset-cache

dataset-check: ## the pin agrees with contract/_meta.json, and sggs-data@commit publishes it
	python3 scripts/data/fetch_dataset.py --check-repo
	python3 scripts/data/fetch_dataset.py --check-pin

check-versions: ## assert the platform version is unified across its 5 locations
	python3 scripts/release/check_versions.py

test-web: ## platform tests: API, contract, OpenAPI, web gates (webapp/tests)
	python3 -m unittest discover -s webapp/tests -v

test-frontend: ## frontend build + pahar vectors
	cd frontend && npm ci && npm run build && npm run test:pahar

contract: ## regenerate golden vectors and fail if they drift
	python3 tools/gen_golden_vectors.py && git diff --exit-code -- 'contract/*.ndjson'

harnesses: ## search regression harnesses (roundtrip + casual quotes) → qa/results/
	python3 tools/roundtrip_harness.py
	python3 tools/casual_quote_harness.py

canary: ## production serves the pinned scripture byte for byte (sample of lines + whole Angs, API and site)
	python3 tools/data_canary.py --origin https://sggs-knowledge-base.onrender.com --origin https://gurbanisoul.com

slices: ## cut every service's database slice from the pinned DB into build/slices/ (proven equal in content)
	for m in reader search verify insights knowledge; do python3 tools/slice_db.py --modules $$m --out build/slices/$$m.sqlite || exit 1; done

ci: check-versions dataset-check test-web contract docs-check ## run the gates CI runs
	@echo "make ci: PASS"

# ── the wiki (docs-site/ over docs/; docs.gurbanisoul.com) ───────────────────
docs-check: ## docs gates: frontmatter, links, widgets, Mermaid palette, scripture rule, posters, drift vs code, site config, sibling pin, generated pages
	python3 tools/docs_check.py
	python3 tools/gen_route_table.py --check
	python3 tools/fetch_sibling_docs.py --check
	python3 -m unittest discover -s tools/tests
docs: ## build the wiki (installs pinned sibling docs; renders every Mermaid fence; validates links)
	python3 tools/fetch_sibling_docs.py
	cd docs-site && npm ci && npm run test:unit && node scripts/build-posters.mjs --check && npm run build && npm run check:all
docs-dev: ## serve the wiki locally on :4322 (proxies /api to a local serve.py on :7777)
	python3 tools/fetch_sibling_docs.py
	cd docs-site && npm run dev
posters: ## regenerate the wiki's posters from docs-site/posters/*.mjs into docs/diagrams/posters/
	cd docs-site && node scripts/build-posters.mjs
docs-e2e: docs ## end-to-end + accessibility suite against the built wiki (mocked API)
	cd docs-site && npx playwright install chromium && npm run test:e2e

openapi: ## regenerate contract/openapi.json (26 routes; schemas inferred from real responses) — test-web fails if stale
	python3 tools/gen_openapi.py

contract-http: ## replay the golden contract over HTTP against a running API: make contract-http BASE=http://127.0.0.1:7777
	@test -n "$(BASE)" || { echo "usage: make contract-http BASE=<api origin>"; exit 2; }
	python3 tools/contract_http.py --base "$(BASE)"

release: ## bump the unified version everywhere: make release VERSION=1.2.0
	@test -n "$(VERSION)" || (echo "usage: make release VERSION=X.Y.Z"; exit 1)
	python3 scripts/release/bump.py $(VERSION)
	python3 scripts/release/check_versions.py

# ── delivery tooling (docs/engineering/delivery.md) ─────────────────────────
pr-checks: ## watch a PR's checks until they finish: make pr-checks PR=<n>
	@test -n "$(PR)" || { echo "usage: make pr-checks PR=<number>"; exit 2; }
	bash scripts/ci/wait_pr_checks.sh $(PR)
release-preflight: ## release readiness: trunk green, versions unified, CHANGELOG section, nothing open
	bash scripts/release/release_preflight.sh
watch-deploy: ## follow the production deploy gate by gate (SHA defaults to origin/main)
	bash scripts/release/watch_deploy.sh $(SHA)
verify-prod: ## prove what production serves: make verify-prod [ARGS="--commit <sha> --version X.Y.Z"]
	python3 scripts/ops/verify_prod.py $(ARGS)
