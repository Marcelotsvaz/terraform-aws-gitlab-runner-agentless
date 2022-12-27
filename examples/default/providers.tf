# 
# VAZ Projects
# 
# 
# Author: Marcelo Tellier Sartori Vaz <marcelotsvaz@gmail.com>



provider "aws" {
	default_tags { tags = local.default_tags }
}


provider "gitlab" {
	token = var.gitlab_access_token
}