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
                        "MaxConcurrency": 8,
                        "ItemProcessor": {
                            "ProcessorConfig": {
                                "Mode": "INLINE"
                            },
                            "StartAt": "ECS Download Bronze Partitions",
                            "States": {
                                "ECS Download Bronze Partitions": {
                                    "Type": "Task",
                                    "Resource": "arn:aws:states:::ecs:runTask.sync",
                                    "Catch": [
                                        {
                                            "ErrorEquals": ["States.ALL"],
                                            "Next": "IgnoreErrorPassState"
                                        }
                                    ],
                                    "Parameters": {
                                        "LaunchType": "FARGATE",
                                        "Cluster": "${ecs_cluster}",
                                        "TaskDefinition": "${handler_bronze_layer_worker}:${handler_bronze_layer_worker_revision}",
                                        "Overrides": {
                                            "ContainerOverrides": [
                                                {
                                                    "Name": "${container_name}",
                                                    "Environment": [
                                                        {
                                                            "Name": "STATE_DATA",
                                                            "Value.$": "States.JsonToString($)"
                                                        },
                                                        {
                                                            "Name": "SWELL_TAGS_BUCKET",
                                                            "Value.$": "States.Format('s3://{}',$.partition_manifest.Bucket)"
                                                        }
                                                    ]
                                                }
                                            ]
                                        },
                                        "NetworkConfiguration": {
                                            "AwsvpcConfiguration": {
                                                "Subnets": [
                                                    "${ecs_private_subnet_0}",
                                                    "${ecs_private_subnet_1}"
                                                ],
                                                "SecurityGroups": [
                                                    "${ecs_task_security_group}"
                                                ],
                                                "AssignPublicIp": "DISABLED"
                                            }
                                        }
                                    },
                                    "End": true
                                },
                                 "IgnoreErrorPassState": {
                                    "Type": "Pass",
                                    "Result": { "status": "SKIPPED_Due_To_Error" },
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