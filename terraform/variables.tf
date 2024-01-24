variable "indexify_db_instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
  default     = "db.t3.small"
}

variable "indexify_db_name" {
  description = "The name of the database"
  type        = string
  default     = "indexify"
}

variable "indexify_db_username" {
  description = "The username for the database"
  type        = string
  default     = "indexify"
}

variable "indexify_db_password" {
  description = "The password for the database"
  type        = string
  default     = "changeme" # changeme
  sensitive   = true
}

variable "indexify_s3_bucket_name" {
  description = "Indexify s3 bucket name that indexify server will use"
  type        = string
  default     = "indexify-bucket-name" # changeme
  sensitive   = true
}
