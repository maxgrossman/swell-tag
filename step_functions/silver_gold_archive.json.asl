{
    "Comment": "Backfills swell tag archive",
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
            "Next": "Make Baseline"
        },
        "Make Baseline": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "OutputPath": "$.Payload",
            "Parameters": {
                "FunctionName": "${handler_select_full}",
                "Payload": {
                    "ranges": [],
                    "models": [
                        "coast.buffered_h3",
                        "coast.lines",
                        "coast.cells_lookup",
                        "ndbc_duck.archive",
                        "ndbc_duck.archive_realtime",
                        "ndbc_duck.bouy_history",
                        "ushlc.archive",
                        "ushlc.stations",
                        "era5_duck.archive"
                    ]
                }
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
            "Comment": "Run lambda handler that validates 'baseline', the archive, stations, and coast h3s exist.",
            "Next": "Choice"
        },
        "Choice": {
            "Type": "Choice",
            "Choices": [
                {
                    "Variable": "$.result",
                    "StringEquals": "missing_dependencies",
                    "Next": "Plan All Models",
                    "Assign": {
                        "lambdaArn": "${handler_initialize_models}"
                    }
                },
                {
                    "Variable": "$.result",
                    "StringEquals": "have_dependencies",
                    "Next": "Find Missing ERA5",
                    "Assign": {
                        "lambdaArn": "${handler_era5_get_missing}"
                    }
                }
            ],
            "Comment": "Takes output of baseline validation where we see if we need to baseline it, then does that."
        },
        "Plan All Models": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "OutputPath": "$.Payload",
            "Parameters": {
                "FunctionName": "${handler_initialize_models}",
                "Payload": {
                    "ranges": [],
                    "models": [
                        "coast.buffered_h3",
                        "coast.lines",
                        "coast.cells_lookup",
                        "ndbc_duck.archive",
                        "ndbc_duck.archive_realtime",
                        "ndbc_duck.bouy_history",
                        "ushlc.archive",
                        "ushlc.stations",
                        "era5_duck.archive"
                    ]
                }
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
            "Next": "Find Missing ERA5",
            "Comment": "fills the archive tables, the bouy & station tables, the coast h3 cell tables, and makes empty tables that hold all our data"
        },
        "Find Missing ERA5": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "OutputPath": "$.Payload",
            "Parameters": {
                "Payload.$": "$",
                "FunctionName": "${handler_era5_get_missing}"
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
            "Next": "Map"
        },
        "Map": {
            "Type": "Map",
            "MaxConcurrency": 10,
            "ItemProcessor": {
                "ProcessorConfig": {
                    "Mode": "INLINE"
                },
                "StartAt": "ERA5 to Parquet",
                "States": {
                    "ERA5 to Parquet": {
                        "Type": "Task",
                        "Resource": "arn:aws:states:::lambda:invoke",
                        "OutputPath": "$.Payload",
                        "Parameters": {
                            "Payload.$": "$",
                            "FunctionName": "${handler_era5_netcdf_to_geoparquet_handler}"
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
                        "End": true,
                        "Comment": "downloads the era 5 wind components from the open data bucket, masks them to the coast buffer, then writes geoparquet to s3 bucket"
                    }
                }
            },
            "Next": "Yearly Missing Intervals",
            "ItemsPath": "$.era5_to_backfill",
            "ResultSelector": {
                "era5_to_backfill": "$"
            }
        },
        "Yearly Missing Intervals": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "OutputPath": "$.Payload",
            "Parameters": {
                "Payload.$": "$",
                "FunctionName": "${handler_build_missing_intervals}"
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
            "Next": "Backfill Model",
            "Comment": "Looks through all archive tables, sees the 'merged interval' that is missing and returns it in yearly chunks"
        },
        "Backfill Model": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "OutputPath": "$.Payload",
            "Parameters": {
                "Payload.$": "$",
                "FunctionName": "${handler_select_interval}"
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