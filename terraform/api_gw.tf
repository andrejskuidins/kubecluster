# IAM role for Lambda execution
resource "aws_iam_role" "lambda_role" {
  name = "hello_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create Lambda function
resource "aws_lambda_function" "hello_lambda" {
  function_name = "hello_world"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "lambda_function.zip"

  # Ensure you create a lambda_function.zip file with index.js containing the handler function
  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      ENVIRONMENT = "production"
    }
  }
}

# Enable CloudWatch logging for Lambda
resource "aws_cloudwatch_log_group" "hello_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.hello_lambda.function_name}"
  retention_in_days = 14
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "hello_api" {
  name        = "HelloAPI"
  description = "API Gateway for Hello Lambda"
}

# API Gateway Resource
resource "aws_api_gateway_resource" "hello_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  parent_id   = aws_api_gateway_rest_api.hello_api.root_resource_id
  path_part   = "hello"
}

# API Gateway Method
resource "aws_api_gateway_method" "hello_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  resource_id   = aws_api_gateway_resource.hello_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Integration
resource "aws_api_gateway_integration" "hello_integration" {
  rest_api_id             = aws_api_gateway_rest_api.hello_api.id
  resource_id             = aws_api_gateway_resource.hello_resource.id
  http_method             = aws_api_gateway_method.hello_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_lambda.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.hello_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "hello_deployment" {
  depends_on = [
    aws_api_gateway_integration.hello_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  stage_name  = "prod"
}

# Enable CloudWatch logs for API Gateway
resource "aws_api_gateway_method_settings" "hello_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  stage_name  = aws_api_gateway_deployment.hello_deployment.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
    data_trace_enabled = true
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.hello_api.id}/${aws_api_gateway_deployment.hello_deployment.stage_name}"
  retention_in_days = 7
}

# Output the API Gateway URL
output "api_url" {
  value = "${aws_api_gateway_deployment.hello_deployment.invoke_url}${aws_api_gateway_resource.hello_resource.path}"
}