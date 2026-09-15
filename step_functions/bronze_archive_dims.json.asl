{
    "Comment": "Backfills swell tag bronze layer",
    "StartAt": "Build Archives",
    "States": {
        "Build Archives": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "OutputPath": "$.Payload",
            "Parameters": {
                "FunctionName": "${handler_build_archives}",
                "Payload.$": "$"
            },
            "Retry": [
                {
                    "ErrorEquals": [
                        "Lambda.ServiceException",
                        "Lambda.AWSLambdaException",
                        "Lambda.SdkClientException",
                        "Lambda.TooManyRequestsException"
                    ],
                    "IntervalSeconds": 1,
                    "MaxAttempts": 3,
                    "BackoffRate": 2,
                    "JitterStrategy": "FULL"
                }
            ],
            "End": true
        }
    },
    "QueryLanguage": "JSONPath"
}