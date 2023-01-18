# 
# VAZ Projects
# 
# 
# Author: Marcelo Tellier Sartori Vaz <marcelotsvaz@gmail.com>



# Name.
#-------------------------------------------------------------------------------
variable "name" {
	description = "Name of the function."
	type = string
}

variable "identifier" {
	description = "Unique identifier used in resources that need a unique name."
	type = string
}

variable "prefix" {
	description = "Unique prefix used in resources that need a globally unique name."
	type = string
}


# Code.
#-------------------------------------------------------------------------------
variable "source_dir" {
	description = "Path of module."
	type = string
}

variable "handler" {
	description = "Lambda function entrypoint."
	type = string
}

variable "timeout" {
	description = "Lambda function timeout."
	type = number
	default = 30
}

variable "parameters" {
	description = "Parameters automatically injected into module."
	type = any
	default = {}
}

variable "environment" {
	description = "Environment variables."
	type = map( string )
	default = {}
}


# Lambda.
#-------------------------------------------------------------------------------
variable "create_url" {
	description = "Create Lambda function URL."
	type = bool
	default = false
}


# Permissions.
#-------------------------------------------------------------------------------
variable "policies" {
	description = "Set of policies for the Lambda Function IAM role."
	type = set( object( { json = string } ) )
	default = []
}



# Locals.
#-------------------------------------------------------------------------------
locals {
	lambda_function_name = "${var.prefix}-${var.identifier}-lambda"	# Avoid cyclic dependency.
}