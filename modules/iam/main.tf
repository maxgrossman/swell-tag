data "aws_iam_role" "power_user" {
  name = "AWSReservedSSO_PowerUserAccess_5a9ad12fe69c1818"
}

data "aws_iam_role" "admin_user" {
  name = "AWSReservedSSO_AdministratorAccess_3befbc9495cbc295"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy" "basic_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "swell_tags_step" {
  name               = "swell-tags-step"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = {
    Name      = "swell-tags-step"
    Service   = "lambda"
    ManagedBy = "tofu"
    Environment = "prod"
  }
}

resource "aws_iam_role_policy_attachment" "basic_execution_role_attach" {
  role       = aws_iam_role.swell_tags_step.name
  policy_arn = data.aws_iam_policy.basic_execution_role.arn
}


output "swell_tags_step_role_name" { 
    value = aws_iam_role.swell_tags_step.name
}

output "swell_tags_step_role" { 
    value = aws_iam_role.swell_tags_step.arn
}

output "power_user_role" {
    value = data.aws_iam_role.power_user.arn
}

output "admin_user_role" {
    value = data.aws_iam_role.admin_user.arn
}