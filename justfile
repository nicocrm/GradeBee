# GradeBee Build & Deploy Manager
# Justfile to replace Makefile complexity

# Default environment
env := "dev"

# Configuration
web_outputdir := "app/build/web"
publish_s3_bucket := "gradebee.bytemypython.com"
amplify_app_id := "d3f4jzff8y6lyx"

# Available environments (used in validation)

# Set environment and prepare configuration files
@env env_name:
    #!/usr/bin/env bash
    set -e
    
    # Validate environment
    if [[ ! " dev prod test " =~ " {{env_name}} " ]]; then
        echo "❌ Invalid environment: {{env_name}}"
        echo "Available environments: dev, prod, test"
        exit 1
    fi
    
    echo "🔧 Setting up environment: {{env_name}}"
    
    # Check if environment directory exists
    if [ ! -d "envs/{{env_name}}" ]; then
        echo "❌ Environment directory not found: envs/{{env_name}}"
        exit 1
    fi
    
    # Check if appwrite.json exists
    if [ ! -f "envs/{{env_name}}/appwrite.json" ]; then
        echo "❌ Missing appwrite.json for environment: {{env_name}}"
        exit 1
    fi
    
    # Copy environment files
    cp "envs/{{env_name}}/appwrite.json" "appwrite.json"
    echo "✅ Copied appwrite.json"
    
    # Copy .env if it exists
    if [ -f "envs/{{env_name}}/.env" ]; then
        cp "envs/{{env_name}}/.env" ".env"
        echo "✅ Copied .env"
    else
        echo "⚠️  No .env file found for environment: {{env_name}}"
        echo "   You may need to copy from env.sample and configure it"
    fi
    
    # Generate app/.env
    if [ -f ".env" ] && [ -f "app/env.source" ]; then
        sh -c 'set -a && . ./.env && envsubst < app/env.source > app/.env'
        echo "✅ Generated app/.env"
    fi
    
    # Generate functions/.env
    if [ -f ".env" ] && [ -f "functions/env.source" ]; then
        sh -c 'set -a && . ./.env && envsubst < functions/env.source > functions/.env'
        echo "✅ Generated functions/.env"
    fi
    
    echo "🎉 Environment '{{env_name}}' is ready!"

# Show current environment status
status:
    #!/usr/bin/env bash
    echo "🔍 Environment Status:"
    echo ""
    for env in dev prod test; do
        echo -n "  $env: "
        if [ -d "envs/$env" ] && [ -f "envs/$env/appwrite.json" ]; then
            echo "✅ Ready"
        else
            echo "❌ Not ready"
        fi
    done
    echo ""

# Appwrite operations
@push env_name:
    #!/usr/bin/env bash
    echo "📤 Pushing to Appwrite..."
    appwrite push
    echo "✅ Push completed"

@pull env_name:
    #!/usr/bin/env bash
    echo "📥 Pulling from Appwrite..."
    appwrite pull
    cp appwrite.json "envs/{{env_name}}/appwrite.json"
    echo "✅ Pull completed and saved to envs/{{env_name}}/"

# Promote dev configuration to production
promote:
    #!/usr/bin/env bash
    echo "⚠️  This will promote dev configuration to production"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🚀 Promoting dev to prod..."
        python scripts/update_appwrite_project.py dev prod
        echo "✅ Promotion completed"
    else
        echo "❌ Promotion cancelled"
    fi

# Web build and deploy
build-web:
    #!/usr/bin/env bash
    echo "🔨 Building Flutter web app..."
    cd app && flutter build web
    cd ..
    echo "✅ Web build completed"

@publish-web env_name:
    #!/usr/bin/env bash
    echo "🌐 Publishing web app to S3..."
    aws s3 sync "{{web_outputdir}}"/ "s3://{{publish_s3_bucket}}/{{env_name}}" --acl public-read --delete
    echo "✅ S3 sync completed"
    
    echo "🚀 Starting Amplify deployment..."
    aws amplify start-deployment --app-id "{{amplify_app_id}}" --branch-name "{{env_name}}" --source-url "s3://{{publish_s3_bucket}}/{{env_name}}/" --source-url-type BUCKET_PREFIX
    echo "✅ Amplify deployment started"

# Full deployment (build + publish)
@deploy env_name:
    #!/usr/bin/env bash
    echo "🔨 Building Flutter web app..."
    cd app && flutter build web
    cd ..
    echo "✅ Web build completed"
    
    echo "🌐 Publishing web app to S3..."
    aws s3 sync "{{web_outputdir}}"/ "s3://{{publish_s3_bucket}}/{{env_name}}" --acl public-read --delete
    echo "✅ S3 sync completed"
    
    echo "🚀 Starting Amplify deployment..."
    aws amplify start-deployment --app-id "{{amplify_app_id}}" --branch-name "{{env_name}}" --source-url "s3://{{publish_s3_bucket}}/{{env_name}}/" --source-url-type BUCKET_PREFIX
    echo "✅ Amplify deployment started"
    
    echo "🎉 Full deployment completed for {{env_name}}!"

# Development helpers
@dev-setup env_name:
    #!/usr/bin/env bash
    echo "🛠️  Setting up development environment..."
    echo "Environment: {{env_name}}"
    echo "Ready for development!"

# Clean build artifacts
clean:
    #!/usr/bin/env bash
    echo "🧹 Cleaning build artifacts..."
    rm -rf app/build/
    rm -f app/.env functions/.env .env appwrite.json
    echo "✅ Clean completed"

# Show help with all available commands
help:
    #!/usr/bin/env bash
    echo "🐝 GradeBee Build & Deploy Manager"
    echo "=================================="
    echo ""
    echo "Current environment: {{env}}"
    echo ""
    echo "📋 Available Commands:"
    echo ""
    echo "  Environment Management:"
    echo "    just env <name>        Set environment (dev/prod/test)"
    echo "    just status            Show environment status"
    echo "    just dev-setup         Setup development environment"
    echo ""
    echo "  Appwrite Operations:"
    echo "    just push              Push to Appwrite (current env)"
    echo "    just pull              Pull from Appwrite (current env)"
    echo "    just promote           Promote dev to prod"
    echo ""
    echo "  Web Operations:"
    echo "    just build-web         Build Flutter web app"
    echo "    just publish-web       Publish web app (current env)"
    echo "    just deploy            Full deployment (current env)"
    echo ""
    echo "  Utilities:"
    echo "    just clean             Clean build artifacts"
    echo "    just help              Show this help"
    echo "    just --list            List all available commands"
    echo ""
    echo "💡 Examples:"
    echo "  just env prod            # Switch to production"
    echo "  just deploy              # Deploy current environment"
    echo "  just env dev && just push # Switch to dev and push"
    echo ""
