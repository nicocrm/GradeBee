ENV ?= dev
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

.PHONY: push pull
push: env
	appwrite push $(ARGS)

pull: env
	appwrite pull $(ARGS)
	cp appwrite.json envs/${ENV}/appwrite.json

promote:
	python scripts/update_appwrite_project.py dev prod

# set up for prod / dev
.PHONY: env
env: envs/${ENV}/appwrite.json
	cp envs/${ENV}/appwrite.json appwrite.json
	cp envs/${ENV}/.env .env
	make app/.env functions/.env

app/.env: .env app/env.source
	sh -c 'set -a && . ./.env && envsubst < app/env.source > app/.env'

functions/.env: .env functions/env.source
	sh -c 'set -a && . ./.env && envsubst < functions/env.source > functions/.env'

# to ignore targets that don't exist, so we can do "make push functions"
%:
	@: