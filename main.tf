terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  access_key = ""
  secret_key = ""
}

resource "aws_dynamodb_table" "cloud" {
  name           = "cloudtest"
  billing_mode   = "PROVISIONED"
  read_capacity  = "30"
  write_capacity = "30"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"
  }

  ttl {
    enabled        = true
    attribute_name = "expiryPeriod"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
  lifecycle {
    ignore_changes = [
      "write_capacity", "read_capacity"
    ]
  }
}

# BEGIN: Codigos que van a contener las funciones lambda
data "archive_file" "function_get" {
  type = "zip"
  source_file = "${path.module}/code/function_get.js"
  output_path = "${path.module}/code/zip/function_get.zip"
}

data "archive_file" "function_post" {
  type = "zip"
  source_file = "${path.module}/code/function_post.js"
  output_path = "${path.module}/code/zip/function_post.zip"
}

data "archive_file" "function_put" {
  type = "zip"
  source_file = "${path.module}/code/function_put.js"
  output_path = "${path.module}/code/zip/function_put.zip"
}

data "archive_file" "function_delete" {
  type = "zip"
  source_file = "${path.module}/code/function_delete.js"
  output_path = "${path.module}/code/zip/function_delete.zip"
}
# END: Codigos que van a contener las funciones lambda

resource "aws_iam_role" "iam_for_lambda" {
  name = "persistence"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb-lambda-policy" {
  name = "dynamodb_lambda_policy"
  role = aws_iam_role.iam_for_lambda.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["dynamodb:*"],
        "Resource" : "${aws_dynamodb_table.cloud.arn}"
      }
    ]
  })
}

# BEGIN: Creacion de las funciones lambda
resource "aws_lambda_function" "function_get" {
  environment {
    variables = {
      TABLE = aws_dynamodb_table.cloud.name
    }
  }

  function_name = "FunctionGet"
  filename = data.archive_file.function_get.output_path
  source_code_hash = data.archive_file.function_get.output_base64sha256
  role = aws_iam_role.iam_for_lambda.arn
  handler = "function_get.handler"
  runtime = "nodejs12.x"
}

resource "aws_lambda_function" "function_post" {
  environment {
    variables = {
      TABLE = aws_dynamodb_table.cloud.name
    }
  }

  function_name = "FunctionPost"
  filename = data.archive_file.function_post.output_path
  source_code_hash = data.archive_file.function_post.output_base64sha256
  role = aws_iam_role.iam_for_lambda.arn
  handler = "function_post.handler"
  runtime = "nodejs12.x"
}

resource "aws_lambda_function" "function_put" {
  environment {
    variables = {
      TABLE = aws_dynamodb_table.cloud.name
    }
  }

  function_name = "FunctionPut"
  filename = data.archive_file.function_put.output_path
  source_code_hash = data.archive_file.function_put.output_base64sha256
  role = aws_iam_role.iam_for_lambda.arn
  handler = "function_put.handler"
  runtime = "nodejs12.x"
}

resource "aws_lambda_function" "function_delete" {
  environment {
    variables = {
      TABLE = aws_dynamodb_table.cloud.name
    }
  }

  function_name = "FunctionDelete"
  filename = data.archive_file.function_delete.output_path
  source_code_hash = data.archive_file.function_delete.output_base64sha256
  role = aws_iam_role.iam_for_lambda.arn
  handler = "function_delete.handler"
  runtime = "nodejs12.x"
}
# END: Creacion de las funciones lambda

resource "aws_apigatewayv2_api" "lambda" {
  name = "api_gw_persistence"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  name = "api"
  api_id = aws_apigatewayv2_api.lambda.id
  auto_deploy = true
}

# BEGIN: Integrar las con la api gt funciones lambda
resource "aws_apigatewayv2_integration" "function_get" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.function_get.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "function_post" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.function_post.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "function_put" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.function_put.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "function_delete" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.function_delete.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}
# END: Integrar las con la api gt funciones lambda

# BEGIN: Rutas de api gt para las funciones lambda
resource "aws_apigatewayv2_route" "function_get" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /items"
  target    = "integrations/${aws_apigatewayv2_integration.function_get.id}"
}

resource "aws_apigatewayv2_route" "function_post" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /items"
  target    = "integrations/${aws_apigatewayv2_integration.function_post.id}"
}

resource "aws_apigatewayv2_route" "function_put" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "PUT /items"
  target    = "integrations/${aws_apigatewayv2_integration.function_put.id}"
}

resource "aws_apigatewayv2_route" "function_delete" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "DELETE /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.function_delete.id}"
}
# END: Rutas de api gt para las funciones lambda

resource "aws_lambda_permission" "api_gw_js" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function_get.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "function_post" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function_post.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "function_put" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function_put.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "function_delete" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function_delete.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}