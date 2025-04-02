import boto3
import json

#  Map impacted entity names to EC2 instance IDs
INSTANCE_MAPPING = {
    "mt-test-win2016": "i-0cca2e61e3dac33fb",
    "mt-test-win01": "i-0971f52241345333b"
}

def lambda_handler(event, context):
    #  Log the received event for debugging
    print("Received event:", json.dumps(event))

    try:
        #  Ensure the request has a body
        if "body" not in event or event["body"] is None:
            raise ValueError("Missing body in request")

        body = json.loads(event["body"])  

        #  Extract impacted entity
        impacted_entities = body.get("impactedEntities", [])

        if not impacted_entities:
            return {
                'statusCode': 400,
                'body': json.dumps("Error: No impactedEntities found in webhook payload.")
            }

        #  Find the first matching EC2 instance ID
        instance_id = None
        for entity in impacted_entities:
            if entity in INSTANCE_MAPPING:
                instance_id = INSTANCE_MAPPING[entity]
                break  # Stop at the first valid match

        if not instance_id:
            return {
                'statusCode': 400,
                'body': json.dumps("Error: No matching EC2 instance found for impactedEntities.")
            }

    except (json.JSONDecodeError, ValueError) as e:
        return {
            'statusCode': 400,
            'body': json.dumps(f"Error parsing request: {str(e)}")
        }

    #  Use Lambda's IAM role to interact with SSM
    ssm_client = boto3.client("ssm")

    try:
        response = ssm_client.send_command(
            InstanceIds=[instance_id],  
            DocumentName="AWS-RunPowerShellScript",
            Parameters={"commands": ["powershell.exe -File C:\\mt\\restart.ps1"]}
        )
        return {
            'statusCode': 200,
            'body': json.dumps(f'Successfully sent restart command to {instance_id}')
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
