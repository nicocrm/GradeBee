terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0"
}

provider "scaleway" {
  project_id = var.project_id
  region = var.region
  zone   = "${var.region}-1"
}

# --- Object Storage for frontend SPA ---

resource "scaleway_object_bucket" "frontend" {
  name = "gradebee-frontend"
}

resource "scaleway_object_bucket_acl" "frontend" {
  bucket = scaleway_object_bucket.frontend.id
  acl    = "public-read"
}

resource "scaleway_object_bucket_website_configuration" "frontend" {
  bucket = scaleway_object_bucket.frontend.name

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# --- Serverless Function for backend ---

resource "scaleway_function_namespace" "gradebee" {
  name = "gradebee"

  environment_variables = {
    ALLOWED_ORIGIN = var.frontend_url
  }

  secret_environment_variables = {
    CLERK_SECRET_KEY = var.clerk_secret_key
  }
}

resource "scaleway_function" "api" {
  namespace_id = scaleway_function_namespace.gradebee.id
  name         = "gradebee-api"
  runtime      = "go124"
  handler      = "Handle"
  privacy      = "public"
  min_scale    = 0
  max_scale    = 5
  memory_limit = 256
  timeout      = 30
  zip_file     = "${path.module}/../dist/functions/backend.zip"
  zip_hash     = filesha256("${path.module}/../dist/functions/backend.zip")

  deploy = true
}
