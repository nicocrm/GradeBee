variable "region" {
  description = "Scaleway region"
  type        = string
  default     = "fr-par"
}

variable "frontend_url" {
  description = "Frontend URL for CORS (e.g. https://gradebee.example.com)"
  type        = string
}

variable "clerk_secret_key" {
  description = "Clerk secret key for backend auth"
  type        = string
  sensitive   = true
}

variable "project_id" {
  description = "Scaleway project ID"
}
