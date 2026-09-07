{
    "Comment": "Backfills swell tag bronze layer",
    "StartAt": "Build Archives",
    "States": {
        "Build Archives": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "OutputPath": "$.Payload",
            "Parameters": {
                "Payload.$": "$",
                "FunctionName": "${handler_build_archives}"
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
            "Next": "build_bronze_partitions"
        },
        "build_bronze_partitions": {
            "Type": "Map",
            "ItemProcessor": {
                "ProcessorConfig": {
                    "Mode": "INLINE"
                },
                "StartAt": "Compute New Bronze Partitions",
                "States": {
                    "Compute New Bronze Partitions": {
                        "Type": "Task",
                        "Resource": "arn:aws:states:::lambda:invoke",
                        "OutputPath": "$.Payload",
                        "Parameters": {
                            "Payload.$": "$",
                            "FunctionName": "${handler_bronze_partitions}"
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
                        "Next": "Warehouse Bronze Partitions"
                    },
                    "Warehouse Bronze Partitions": {
                        "Type": "Map",
                        "MaxConcurrency": 4,
                        "ItemProcessor": {
                            "ProcessorConfig": {
                                "Mode": "INLINE"
                            },
                            "StartAt": "Download Bronze Partitions",
                            "States": {
                                "Download Bronze Partitions": {
                                    "Type": "Task",
                                    "Resource": "arn:aws:states:::lambda:invoke",
                                    "OutputPath": "$.Payload",
                                    "Parameters": {
                                        "Payload.$": "$",
                                        "FunctionName": "${handler_bronze_layer}"
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
                            }
                        },
                        "End": true
                    }
                }
            },
            "End": true
        }
    },
    "QueryLanguage": "JSONPath"
}