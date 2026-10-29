{
    "Comment": "Backfills swell tag archive",
    "StartAt": "Initialize Missing Baseline",
    "States": {
        "Initialize Missing Baseline": {
            "Type": "Task",
            "Resource": "arn:aws:states:::ecs:runTask.waitForTaskToken",
            "Parameters": {
                "LaunchType": "FARGATE",
                "Cluster": "${ecs_cluster}",
                "TaskDefinition": "${handler_select_baseline_worker}:${handler_select_baseline_worker_revision}",
                "Overrides": {
                    "ContainerOverrides": [
                        {
                            "Name": "${handler_select_baseline_worker_container_name}",
                            "Environment": [
                                {
                                    "Name": "TASK_TOKEN",
                                    "Value.$": "$$.Task.Token"
                                },
                                {
                                    "Name": "STATE_DATA",
                                    "Value.$": "States.JsonToString($)"
                                },
                                {
                                    "Name": "PGHOST",
                                    "Value": "${PGHOST}"
                                },
                                {
                                    "Name": "PGUSER",
                                    "Value": "${PGUSER}"
                                },
                                {
                                    "Name": "PGDATABASE",
                                    "Value": "${PGDATABASE}"
                                },
                                {
                                    "Name": "PGPORT",
                                    "Value": "${PGPORT}"
                                },
                                {
                                    "Name": "RDSSECRETARN",
                                    "Value": "${RDSSECRETARN}"
                                },
                                {
                                    "Name": "PYTHONPATH",
                                    "Value": "${PYTHONPATH}"
                                },
                                {
                                    "Name": "SQLMESH_GATEWAY",
                                    "Value": "${SQLMESH_GATEWAY}"
                                },
                                {
                                    "Name": "SQLMESH_PATH",
                                    "Value": "${SQLMESH_PATH}"
                                },
                                {
                                    "Name": "SQLMESH_LOG_DIR",
                                    "Value": "${SQLMESH_LOG_DIR}"
                                },
                                {
                                    "Name": "SQLMESH_CONFIG_PATH",
                                    "Value": "${SQLMESH_CONFIG_PATH}"
                                },
                                {
                                    "Name": "SQLMESH_DEBUG",
                                    "Value": "${SQLMESH_DEBUG}"
                                },
                                {
                                    "Name": "SQLMESH_CACHE_DIR",
                                    "Value": "${SQLMESH_CACHE_DIR}"
                                },
                                {
                                    "Name": "SWELL_TAGS_BUCKET",
                                    "Value": "${SWELL_TAGS_BUCKET}"
                                },
                                {
                                    "Name": "MAX_FORK_WORKERS",
                                    "Value": "${MAX_FORK_WORKERS}"
                                },
                                {
                                    "Name": "SQLMESH__DISABLE_ANONYMIZED_ANALYTICS",
                                    "Value": "${SQLMESH__DISABLE_ANONYMIZED_ANALYTICS}"
                                },
                                {
                                    "Name": "SQLMESH_HOME",
                                    "Value": "${SQLMESH_HOME}"
                                },
                                {
                                    "Name": "PGCONNECT_TIMEOUT",
                                    "Value": "${PGCONNECT_TIMEOUT}"
                                },
                                {
                                    "Name": "DUCKLAKE_DATAPATH",
                                    "Value": "${DUCKLAKE_DATAPATH}"
                                },
                                {
                                    "Name": "DATA_INLINING_ROW_LIMIT",
                                    "Value": "${DATA_INLINING_ROW_LIMIT}"
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
                        "AssignPublicIp": "ENABLED"
                    }
                }
            },
            "Next": "Build Intervals"
        },
        "Build Intervals": {
            "Type": "Task",

            "Resource": "arn:aws:states:::ecs:runTask.waitForTaskToken",
            "Parameters": {
                "LaunchType": "FARGATE",
                "Cluster": "${ecs_cluster}",
                "TaskDefinition": "${handler_select_interval_worker}:${handler_select_interval_worker_revision}",
                "Overrides": {
                    "ContainerOverrides": [
                        {
                            "Name": "${handler_select_interval_worker_container_name}",
                            "Environment": [
                                {
                                    "Name": "TASK_TOKEN",
                                    "Value.$": "$$.Task.Token"
                                },
                                {
                                    "Name": "STATE_DATA",
                                    "Value.$": "States.JsonToString($)"
                                },
                                {
                                    "Name": "PGHOST",
                                    "Value": "${PGHOST}"
                                },
                                {
                                    "Name": "PGUSER",
                                    "Value": "${PGUSER}"
                                },
                                {
                                    "Name": "PGPORT",
                                    "Value": "${PGPORT}"
                                },
                                {
                                    "Name": "PGDATABASE",
                                    "Value": "${PGDATABASE}"
                                },
                                {
                                    "Name": "PGCONNECT_TIMEOUT",
                                    "Value": "${PGCONNECT_TIMEOUT}"
                                },
                                {
                                    "Name": "RDSSECRETARN",
                                    "Value": "${RDSSECRETARN}"
                                },
                                {
                                    "Name": "PYTHONPATH",
                                    "Value": "${PYTHONPATH}"
                                },
                                {
                                    "Name": "SQLMESH_GATEWAY",
                                    "Value": "${SQLMESH_GATEWAY}"
                                },
                                {
                                    "Name": "SQLMESH_PATH",
                                    "Value": "${SQLMESH_PATH}"
                                },
                                {
                                    "Name": "SQLMESH_LOG_DIR",
                                    "Value": "${SQLMESH_LOG_DIR}"
                                },
                                {
                                    "Name": "SQLMESH_CONFIG_PATH",
                                    "Value": "${SQLMESH_CONFIG_PATH}"
                                },
                                {
                                    "Name": "SQLMESH_DEBUG",
                                    "Value": "${SQLMESH_DEBUG}"
                                },
                                {
                                    "Name": "SQLMESH_CACHE_DIR",
                                    "Value": "${SQLMESH_CACHE_DIR}"
                                },
                                {
                                    "Name": "SWELL_TAGS_BUCKET",
                                    "Value": "${SWELL_TAGS_BUCKET}"
                                },
                                {
                                    "Name": "MAX_FORK_WORKERS",
                                    "Value": "${MAX_FORK_WORKERS}"
                                },
                                {
                                    "Name": "SQLMESH__DISABLE_ANONYMIZED_ANALYTICS",
                                    "Value": "${SQLMESH__DISABLE_ANONYMIZED_ANALYTICS}"
                                },
                                {
                                    "Name": "SQLMESH_HOME",
                                    "Value": "${SQLMESH_HOME}"
                                },
                                {
                                    "Name": "DUCKLAKE_DATAPATH",
                                    "Value": "${DUCKLAKE_DATAPATH}"
                                },
                                {
                                    "Name": "DATA_INLINING_ROW_LIMIT",
                                    "Value": "${DATA_INLINING_ROW_LIMIT}"
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
                        "AssignPublicIp": "ENABLED"
                    }
                }
            },
            "End": true
        }
    },
    "QueryLanguage": "JSONPath"
}