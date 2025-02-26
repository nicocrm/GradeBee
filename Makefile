ENV ?= dev
WEB_OUTPUTDIR := app/build/web
PUBLISH_S3_BUCKET := gradebee.bytemypython.com

.PHONY: push pull
push: env
	appwrite push

pull: env
	appwrite pull
	cp appwrite.json envs/${ENV}/appwrite.json

promote:
	python scripts/update_appwrite_project.py dev prod

build-web:
	cd app && flutter build web

publish-web: env build-web
	aws s3 sync "$(WEB_OUTPUTDIR)"/ s3://$(PUBLISH_S3_BUCKET)/$(ENV) --acl public-read --delete
	aws amplify start-deployment --app-id gradebee --branch-name $(ENV) --source-url s3://$(PUBLISH_S3_BUCKET)/$(ENV) 

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
