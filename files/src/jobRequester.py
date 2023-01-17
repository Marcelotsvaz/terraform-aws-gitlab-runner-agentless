# 
# VAZ Projects
# 
# 
# Author: Marcelo Tellier Sartori Vaz <marcelotsvaz@gmail.com>



import logging
import os
import requests
import json
import boto3



def main( event, context ):
	logging.getLogger().setLevel( logging.INFO )
	
	
	# Get new jobs.
	runner = event['runner']
	job = requestJob( os.environ['gitlabUrl'], runner )
	if not job:
		logging.warning( f'No jobs available for runner {runner["id"]}.' )
		return
	
	
	# Create worker.
	subnetIds = json.loads( os.environ['subnetIds'] )
	fleetRequest = boto3.client( 'ec2' ).create_fleet(
		Type = 'instant',
		TargetCapacitySpecification = {
			'DefaultTargetCapacityType': 'spot',
			'TotalTargetCapacity': 1,
		},
		LaunchTemplateConfigs = [
			{
				'LaunchTemplateSpecification': {
					'LaunchTemplateId': runner['launch_template_id'],
					'Version': '$Default',
				},
				'Overrides': [ { 'SubnetId': subnetId } for subnetId in subnetIds ],
			},
		],
	)
	
	for error in fleetRequest['Errors']:
		logging.warning( error )
	
	if len( fleetRequest['Instances'] ) == 0:
		logging.error( 'Couldn\'t create worker.' )
		return
	
	
	# Register job.
	jobId = job['job_info']['id']
	workerId = fleetRequest['Instances'][0]['InstanceIds'][0]
	workerType = fleetRequest['Instances'][0]['InstanceType']
	jobs = boto3.resource( 'dynamodb' ).Table( os.environ['jobsTableName'] )
	jobs.put_item(
		Item = {
			'id': jobId,
			'workerId': workerId,
			'data': job,
		}
	)
	
	logging.info( f'Assigned job {jobId} to worker {workerId} ({workerType}) of runner {runner["id"]}.' )



def requestJob( gitlabUrl, runner ):
	'''
	Request a job from GitLab for a specific runner.
	'''
	
	response = requests.post( f'{gitlabUrl}/api/v4/jobs/request', json = {
		'token': runner['authentication_token'],
		'info': {
			'features': {
				'artifacts_exclude': True,
				'artifacts': True,
				'cache': True,
				'cancelable': True,
				'image': True,
				'masking': True,
				'multi_build_steps': True,
				'proxy': False,
				'raw_variables': True,
				'refspecs': True,
				'return_exit_code': True,
				'service_variables': True,
				'services': True,
				'session': True,
				'shared': False,
				'terminal': True,
				'trace_checksum': True,
				'trace_reset': True,
				'trace_size': True,
				'upload_multiple_artifacts': True,
				'upload_raw_artifacts': True,
				'variables': True,
				'vault_secrets': True,
			}
		}
	} )
	
	if response.status_code == 201:
		return response.json()
	elif response.status_code == 204:
		return None
	else:
		raise Exception( f'Invalid status code ({response.status_code}) while requesting job.' )