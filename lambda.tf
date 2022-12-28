# 
# VAZ Projects
# 
# 
# Author: Marcelo Tellier Sartori Vaz <marcelotsvaz@gmail.com>



locals {
	lambda_function_name = "${var.prefix}-${var.identifier}-lambda"	# Avoid cyclic dependency.
}



# 
# Serverless agent.
#-------------------------------------------------------------------------------
resource "aws_lambda_function" "main" {
	function_name = local.lambda_function_name
	role = aws_iam_role.agent.arn
	
	runtime = "python3.9"
	filename = data.archive_file.lambda_module.output_path
	source_code_hash = data.archive_file.lambda_module.output_base64sha256
	handler = "lambda.main"
	timeout = 10
	# reserved_concurrent_executions = 1
	
	environment {
		variables = {
			secretToken = random_password.webhook_token.result
			spotFleetId = aws_spot_fleet_request.main.id
		}
	}
	
	# Make sure the log group is created before the function because we removed the implicit dependency.
	depends_on = [ aws_cloudwatch_log_group.main ]
	
	tags = {
		Name = "${var.name} Lambda"
	}
}


data "archive_file" "lambda_module" {
	type = "zip"
	source_file = "${path.module}/lambda.py"
	output_path = "deployment/${var.prefix}/${var.identifier}/lambda.zip"
}


resource "aws_lambda_function_url" "main" {
	function_name = aws_lambda_function.main.function_name
	authorization_type = "NONE"
}


resource "aws_cloudwatch_log_group" "main" {
	name = "/aws/lambda/${local.lambda_function_name}"
	
	tags = {
		Name = "${var.name} Lambda Log Group"
	}
}



# 
# Lambda IAM Role.
#-------------------------------------------------------------------------------
resource "aws_iam_role" "agent" {
	name = "${var.prefix}-${var.identifier}-lambdaRole"
	assume_role_policy = data.aws_iam_policy_document.agent_assume_role.json
	managed_policy_arns = []
	
	inline_policy {
		name = "${var.prefix}-${var.identifier}-lambdaRolePolicy"
		
		policy = data.aws_iam_policy_document.agent_role.json
	}
	
	tags = {
		Name: "${var.name} Lambda Role"
	}
}


data "aws_iam_policy_document" "agent_assume_role" {
	statement {
		sid = "lambdaAssumeRole"
		
		principals {
			type = "Service"
			identifiers = [ "lambda.amazonaws.com" ]
		}
		
		actions = [ "sts:AssumeRole" ]
	}
}


data "aws_iam_policy_document" "agent_role" {
	# Used in lambda.py.
	statement {
		sid = "ec2ModifySpotFleetRequest"
		
		actions = [ "ec2:ModifySpotFleetRequest" ]
		
		resources = [ "arn:aws:ec2:${data.aws_arn.main.region}:${data.aws_arn.main.account}:spot-fleet-request/${aws_spot_fleet_request.main.id}" ]
	}
	
	# Used by Lambda.
	statement {
		sid = "cloudwatchWriteLogs"
		
		actions = [
			"logs:CreateLogStream",
			"logs:PutLogEvents",
		]
		
		resources = [ "${aws_cloudwatch_log_group.main.arn}:*" ]
	}
}


data "aws_arn" "main" {
	# Get region and account ID to construct Spot Fleet ARN.
	arn = aws_launch_template.main.arn
}