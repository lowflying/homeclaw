# Hetzner Object Storage S3-compatible backend.
# Credentials are read from environment variables:
#   AWS_ACCESS_KEY_ID     → GitHub Actions secret: HOS_ACCESS_KEY
#   AWS_SECRET_ACCESS_KEY → GitHub Actions secret: HOS_SECRET_KEY

terraform {
  backend "s3" {
    bucket = "homeclaw-infra-tfstate"
    key    = "base/terraform.tfstate"
    region = "us-east-1" # dummy value — HOS does not use regions but the backend requires one

    endpoint = "https://nbg1.your-objectstorage.com"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
