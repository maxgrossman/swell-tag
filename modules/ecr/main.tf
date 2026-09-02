resource "aws_ecr_repository" "swell_tags" {
  name                 = "swell-tags"
  image_tag_mutability = "IMMUTABLE" # Prevents tags from being overwritten

  image_scanning_configuration {
    scan_on_push = true # Automatically scans images for vulnerabilities
  }

  tags = {
    Name        = "swell-tags"
    ManagedBy   = "tofu"
    Environment = "prod"
  }
}


output "swell_tags_ecr_repo" {
    value = aws_ecr_repository.swell_tags.name
}