# Hetzner Object Storage S3-compatible backend.
# Credentials are read from environment variables:
#   AWS_ACCESS_KEY_ID     → GitHub Actions secret: HOS_ACCESS_KEY
#   AWS_SECRET_ACCESS_KEY → GitHub Actions secret: HOST_SECRET_KEY  (note: typo in secret name — should be HOS_ but is HOST_)

terraform {
  backend "s3" {
    bucket = "homeclaw"
    key    = "base/terraform.tfstate"
    region = "eu-central" # matches Hetzner Object Storage region

    endpoints = {
      s3 = "https://hel1.your-objectstorage.com"
    }

    skip_credentials_validation  = true
    skip_metadata_api_check      = true
    skip_region_validation       = true
    skip_requesting_account_id   = true
    use_path_style               = true
  }
}
