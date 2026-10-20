data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../build"
  output_path = "${path.module}/lambda.zip"

}

resource "aws_iam_role" "lambda" {
  name = "pokemon-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/pokemon-api"
  retention_in_days = 7
}

resource "aws_lambda_function" "api" {
  function_name    = "pokemon-api"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.13"
  handler          = "main.handler"
  architectures    = ["x86_64"]
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  memory_size      = 256
  timeout          = 10

  depends_on = [
    aws_iam_role_policy_attachment.logs,
    aws_cloudwatch_log_group.lambda,
  ]
}

resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "url_publica" {
  statement_id           = "PermitirFunctionUrlPublica"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.api.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "invocar_via_url" {
  statement_id             = "PermitirInvocarSoloViaUrl"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.api.function_name
  principal                = "*"
  invoked_via_function_url = true
}