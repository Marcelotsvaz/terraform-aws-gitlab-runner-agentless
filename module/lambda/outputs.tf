# 
# VAZ Projects
# 
# 
# Author: Marcelo Tellier Sartori Vaz <marcelotsvaz@gmail.com>



output "function_name" {
	description = "Lambda Function name."
	value = aws_lambda_function.main.function_name
}

output "invoke_arn" {
	description = "Lambda Function invoke ARN."
	value = aws_lambda_function.main.invoke_arn
}

output "function_url" {
	description = "Lambda Function URL."
	value = one( aws_lambda_function_url.main[*].function_url )
}