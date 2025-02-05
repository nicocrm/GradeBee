ENV ?= dev
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

push: appwrite.json
	appwrite push $(ARGS)

pull: appwrite.json
	appwrite pull $(ARGS)
	cp appwrite.json envs/${ENV}/appwrite.json

.PHONY: appwrite.json
appwrite.json: envs/${ENV}/appwrite.json
	cp envs/${ENV}/appwrite.json appwrite.json