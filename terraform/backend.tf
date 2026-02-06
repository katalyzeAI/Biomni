# Uncomment and configure for remote state storage.
# Run `terraform init` after uncommenting.
#
# terraform {
#   backend "s3" {
#     bucket         = "biomni-terraform-state"
#     key            = "ecs/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "biomni-terraform-locks"
#     encrypt        = true
#   }
# }
