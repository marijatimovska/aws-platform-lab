variable "name" {
  description = "Name prefix (e.g. platlab-dev)."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique bucket name (include the account id)."
  type        = string
}
