variable "swell_tags_step_arn" {
    type = string
}

variable "power_user_role_arn" {
    type = string
}
variable "admin_user_role_arn" {
    type = string
}


data "aws_iam_policy_document" "swell_tags_policy" {
  statement {
    sid    = "SwellTagsAllow"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [
        var.power_user_role_arn,
        var.admin_user_role_arn,
        var.swell_tags_step_arn
      ]
    }

    resources = [
      aws_s3_bucket.swell_tags.arn,
      "${aws_s3_bucket.swell_tags.arn}/*"
    ]

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
  }
}

resource "aws_s3_bucket" "swell_tags" {
  bucket = "swell-tags" 

  tags = {
    Name        = "swell-tags"
    ManagedBy   = "tofu"
    Environment = "prod"
  }
}

resource "aws_s3_bucket_policy" "swell_tags" {
  bucket = aws_s3_bucket.swell_tags.id
  policy = data.aws_iam_policy_document.swell_tags_policy.json
}


output "swell_tags_bucket" {
    value = aws_s3_bucket.swell_tags.arn
}
