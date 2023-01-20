# 
# GitLab Serverless Runner Manager
# 
# 
# Author: Marcelo Tellier Sartori Vaz <marcelotsvaz@gmail.com>



# 
# Webhook Handler
#-------------------------------------------------------------------------------
module webhook_handler {
	source = "./module/lambda"
	
	name = "Webhook Handler"
	identifier = "webhookHandler"
	prefix = "${var.prefix}-${var.identifier}"
	
	source_dir = "${path.module}/files/src"
	handler = "manager.webhookHandler.main"
	parameters = { jobMatchersFunctionArn = module.job_matcher.arn }
	
	policies = [ data.aws_iam_policy_document.webhook_handler ]
}


data aws_iam_policy_document webhook_handler {
	statement {
		sid = "invokeJobMatcherFunction"
		
		actions = [ "lambda:InvokeFunction" ]
		
		resources = [ module.job_matcher.arn ]
	}
}


resource aws_lambda_permission webhook_handler {
	function_name = module.webhook_handler.function_name
	statement_id = "lambdaInvokeFunction"
	principal = "apigateway.amazonaws.com"
	action = "lambda:InvokeFunction"
	source_arn = "${aws_apigatewayv2_stage.main.execution_arn}/${replace( aws_apigatewayv2_route.webhook_handler.route_key, " ", "")}"
}



# 
# Job Matcher
#-------------------------------------------------------------------------------
module job_matcher {
	source = "./module/lambda"
	
	name = "Job Matcher"
	identifier = "jobMatcher"
	prefix = "${var.prefix}-${var.identifier}"
	
	source_dir = "${path.module}/files/src"
	handler = "manager.jobMatcher.main"
	parameters = {
		gitlabUrl = var.gitlab_url
		projectToken = gitlab_project_access_token.main.token
		runners = local.runner_config_output
		jobRequesterFunctionArn = module.job_requester.arn
	}
	
	policies = [ data.aws_iam_policy_document.job_matcher ]
}


data aws_iam_policy_document job_matcher {
	statement {
		sid = "invokeJobRequesterFunction"
		
		actions = [ "lambda:InvokeFunction" ]
		
		resources = [ module.job_requester.arn ]
	}
}



# 
# Job Requester
#-------------------------------------------------------------------------------
module job_requester {
	source = "./module/lambda"
	
	name = "Job Requester"
	identifier = "jobRequester"
	prefix = "${var.prefix}-${var.identifier}"
	
	source_dir = "${path.module}/files/src"
	handler = "manager.jobRequester.main"
	parameters = {
		gitlabUrl = var.gitlab_url
		subnetIds = aws_subnet.main[*].id
		jobsTableName = aws_dynamodb_table.jobs.name
	}
	
	policies = [ data.aws_iam_policy_document.job_requester ]
}


data aws_iam_policy_document job_requester {
	statement {
		sid = "putJob"
		
		actions = [ "dynamodb:PutItem" ]
		
		resources = [ aws_dynamodb_table.jobs.arn ]
	}
	
	statement {
		sid = "createWorker"
		
		actions = [
			"ec2:CreateFleet",
			"ec2:RunInstances",
			"ec2:CreateTags",
		]
		
		resources = [ "*" ]
	}
	
	statement {
		sid = "passWorkerRole"
		
		actions = [ "iam:PassRole" ]
		
		resources = [ aws_iam_role.instance.arn ]
	}
}



# 
# Job Provider
#-------------------------------------------------------------------------------
module job_provider {
	source = "./module/lambda"
	
	name = "Job Provider"
	identifier = "jobProvider"
	prefix = "${var.prefix}-${var.identifier}"
	
	source_dir = "${path.module}/files/src"
	handler = "manager.jobProvider.main"
	parameters = {
		runners = local.runner_config_output
		jobsTableName = aws_dynamodb_table.jobs.name
	}
	
	policies = [ data.aws_iam_policy_document.job_provider ]
}


data aws_iam_policy_document job_provider {
	statement {
		sid = "getJob"
		
		actions = [
			"dynamodb:Scan",
			"dynamodb:DeleteItem",
		]
		
		resources = [ aws_dynamodb_table.jobs.arn ]
	}
	
	statement {
		sid = "terminateWorker"
		
		actions = [ "ec2:TerminateInstances" ]
		
		resources = [ "*" ]
	}
}


resource aws_lambda_permission job_provider {
	function_name = module.job_provider.function_name
	statement_id = "lambdaInvokeFunction"
	principal = "apigateway.amazonaws.com"
	action = "lambda:InvokeFunction"
	source_arn = "${aws_apigatewayv2_stage.main.execution_arn}/${replace( aws_apigatewayv2_route.job_provider.route_key, " ", "")}"
}



# 
# Authorizer
#-------------------------------------------------------------------------------
module authorizer {
	source = "./module/lambda"
	
	name = "Authorizer"
	identifier = "authorizer"
	prefix = "${var.prefix}-${var.identifier}"
	
	source_dir = "${path.module}/files/src"
	handler = "manager.authorizer.main"
	parameters = { token = random_password.webhook_token.result }
}


resource aws_lambda_permission authorizer {
	function_name = module.authorizer.function_name
	statement_id = "lambdaInvokeFunction"
	principal = "apigateway.amazonaws.com"
	action = "lambda:InvokeFunction"
	source_arn = "${aws_apigatewayv2_api.main.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.main.id}"
}



# 
# Jobs Database
#-------------------------------------------------------------------------------
resource aws_dynamodb_table jobs {
	name = "${var.prefix}-${var.identifier}-jobs"
	hash_key = "workerId"
	
	billing_mode = "PAY_PER_REQUEST"
	
	attribute {
		name = "workerId"
		type = "S"
	}
	
	tags = {
		Name = "${var.name} Job Database"
	}
}