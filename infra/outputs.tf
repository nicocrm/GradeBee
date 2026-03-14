output "frontend_bucket_endpoint" {
  description = "Frontend website URL"
  value       = scaleway_object_bucket_website_configuration.frontend.website_endpoint
}

output "api_endpoint" {
  description = "Backend function endpoint URL"
  value       = scaleway_function.api.domain_name
}
