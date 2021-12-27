provider "aws" {
   region = "eu-west-3"
}

resource "aws_dynamodb_table" "ddbtable" {
  name             = "lambda-apigateway"
  hash_key         = "id"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.role_for_LDC.id

  policy = file("policy.json")
}


resource "aws_iam_role" "role_for_LDC" {
  name = "lambda-assume-role"
  assume_role_policy = file("assume_role_policy.json")

}


resource "aws_lambda_function" "LambdaFunctionOverHttps" {

  function_name = "LambdaFunctionOverHttps"
  filename      = "LambdaFunctionOverHttps.zip"
  role          = aws_iam_role.role_for_LDC.arn
  handler       = "LambdaFunctionOverHttps.handler"
  runtime       = "nodejs12.x"
}


resource "aws_api_gateway_rest_api" "apiLambda" {
  name        = "DynamoDBOperations"
}

resource "aws_api_gateway_resource" "Resource" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  parent_id   = aws_api_gateway_rest_api.apiLambda.root_resource_id
  path_part   = "DynamoDBManager"
}

resource "aws_api_gateway_method" "Method" {
   rest_api_id   = aws_api_gateway_rest_api.apiLambda.id
   resource_id   = aws_api_gateway_resource.Resource.id
   http_method   = "POST"
   authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambdaInt" {
   rest_api_id = aws_api_gateway_rest_api.apiLambda.id
   resource_id = aws_api_gateway_resource.Resource.id
   http_method = aws_api_gateway_method.Method.http_method

   integration_http_method = "POST"
   type                    = "AWS"
   uri                     = aws_lambda_function.LambdaFunctionOverHttps.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.LambdaFunctionOverHttps.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.apiLambda.id}/*/${aws_api_gateway_method.Method.http_method}${aws_api_gateway_resource.Resource.path}"
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  resource_id = aws_api_gateway_resource.Resource.id
  http_method = aws_api_gateway_method.Method.http_method
  status_code = "200"
  response_models = { "application/json" = "Empty" }
}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  resource_id = aws_api_gateway_resource.Resource.id
  http_method = aws_api_gateway_method.Method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
  # response_parameters = {
  #   "method.response.header.Access-Control-Allow-Origin" = "'*'"
  # }

  depends_on = [
    aws_api_gateway_integration.lambdaInt
  ]
}

# resource "aws_api_gateway_deployment" "apideploy" {
#    depends_on = [aws_api_gateway_integration.lambdaInt]

#    rest_api_id = aws_api_gateway_rest_api.apiLambda.id
#    stage_name  = "Prod"
# }


# resource "aws_lambda_permission" "apigw" {
#    statement_id  = "AllowExecutionFromAPIGateway"
#    action        = "lambda:InvokeFunction"
#    function_name = aws_lambda_function.LambdaFunctionOverHttps.function_name
#    principal     = "apigateway.amazonaws.com"

#    source_arn = "${aws_api_gateway_rest_api.apiLambda.execution_arn}/Prod/POST/myresource"

# }


# output "base_url" {
#   value = aws_api_gateway_deployment.apideploy.invoke_url
# }