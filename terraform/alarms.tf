# ===================================================================
# Resources
# ===================================================================

resource "aws_cloudwatch_metric_alarm" "vault_server_tasks_lo" {
    alarm_name        = "${var.project}-server-tasks-lo"
    alarm_description = "Number of vault server tasks falls bellow the desired threshold."

    namespace = "ECS/ContainerInsights"
    dimensions = {
        ClusterName = aws_ecs_cluster.vault_server.name
        ServiceName = aws_ecs_service.vault_server.name
    }
    metric_name = "RunningTaskCount"

    period    = 60
    statistic = "Minimum"
    unit      = "Count"

    comparison_operator = "LessThanThreshold"
    threshold           = length(aws_instance.vault_server)
    evaluation_periods  = 5

    alarm_actions = [ aws_sns_topic.admin.arn ]
    ok_actions    = [ aws_sns_topic.admin.arn ]

    tags = {
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}

resource "aws_cloudwatch_metric_alarm" "vault_server_instances_lo" {
    alarm_name        = "${var.project}-server-instances-lo"
    alarm_description = "Number of vault server container instances falls bellow the desired threshold."

    namespace = "ECS/ContainerInsights"
    dimensions = {
        ClusterName = aws_ecs_cluster.vault_server.name
    }
    metric_name = "ContainerInstanceCount"

    period    = 60
    statistic = "Minimum"
    unit      = "Count"

    comparison_operator = "LessThanThreshold"
    threshold           = length(aws_instance.vault_server)
    evaluation_periods  = 5

    alarm_actions = [ aws_sns_topic.admin.arn ]
    ok_actions    = [ aws_sns_topic.admin.arn ]

    tags = {
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}

resource "aws_cloudwatch_metric_alarm" "vault_server_memavailable_lo" {
    count = length(aws_instance.vault_server)

    alarm_name        = "${var.project}-server${upper(data.aws_availability_zone.public[count.index].name_suffix)}-memavailable-lo"
    alarm_description = "Memory available on the servers is low."

    namespace = "CWAgent"
    dimensions = {
        InstanceId = aws_instance.vault_server[count.index].id
    }
    metric_name = "mem_available_percent"

    period    = var.enhanced_monitoring ? 300 : 1800
    statistic = "Average"
    unit      = "Percent"

    comparison_operator = "LessThanThreshold"
    threshold           = 15
    evaluation_periods  = var.enhanced_monitoring ? 5 : 3

    alarm_actions = [ aws_sns_topic.admin.arn ]
    ok_actions    = [ aws_sns_topic.admin.arn ]

    tags = {
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}

resource "aws_cloudwatch_metric_alarm" "vault_server_diskused_hi" {
    count = length(aws_instance.vault_server)

    alarm_name        = "${var.project}-server${upper(data.aws_availability_zone.public[count.index].name_suffix)}-diskused-hi"
    alarm_description = "Disk used on the root file system is high."

    namespace = "CWAgent"
    dimensions = {
        InstanceId = aws_instance.vault_server[count.index].id
        fstype     = "ext4"
        path       = "/"
    }
    metric_name = "disk_used_percent"

    period    = var.enhanced_monitoring ? 300 : 1800
    statistic = "Average"
    unit      = "Percent"

    comparison_operator = "GreaterThanThreshold"
    threshold           = 90
    evaluation_periods  = var.enhanced_monitoring ? 5 : 3

    alarm_actions = [ aws_sns_topic.admin.arn ]
    ok_actions    = [ aws_sns_topic.admin.arn ]

    tags = {
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}

resource "aws_cloudwatch_metric_alarm" "vault_server_neterrs_hi" {
    count = length(aws_instance.vault_server)

    alarm_name        = "${var.project}-server${upper(data.aws_availability_zone.public[count.index].name_suffix)}-neterrs-hi"
    alarm_description = "Networks in or out errors is high."

    metric_query {
        id = "errin"

        metric {
            namespace = "CWAgent"
            dimensions = {
                InstanceId = aws_instance.vault_server[count.index].id
                interface  = "eth0"
            }
            metric_name = "net_err_in"

            period = var.enhanced_monitoring ? 300 : 1800
            stat   = "Sum"
            unit   = "Count"
        }
    }

    metric_query {
        id = "errout"

        metric {
            namespace = "CWAgent"
            dimensions = {
                InstanceId = aws_instance.vault_server[count.index].id
                interface  = "eth0"
            }
            metric_name = "net_err_out"

            period = var.enhanced_monitoring ? 300 : 1800
            stat   = "Sum"
            unit   = "Count"
        }
    }

    metric_query {
        id = "err"

        expression  = "errin+errout"
        label       = "net_err"
        return_data = "true"
    }

    comparison_operator = "GreaterThanThreshold"
    threshold           = 100
    evaluation_periods  = var.enhanced_monitoring ? 5 : 3

    alarm_actions = [ aws_sns_topic.admin.arn ]
    ok_actions    = [ aws_sns_topic.admin.arn ]

    tags = {
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}

resource "aws_cloudwatch_metric_alarm" "vault_server_netdrops_hi" {
    count = length(aws_instance.vault_server)

    alarm_name        = "${var.project}-server${upper(data.aws_availability_zone.public[count.index].name_suffix)}-netdrops-hi"
    alarm_description = "Networks in or out drops is high."

    metric_query {
        id = "dropin"

        metric {
            namespace = "CWAgent"
            dimensions = {
                InstanceId = aws_instance.vault_server[count.index].id
                interface  = "eth0"
            }
            metric_name = "net_drop_in"

            period = var.enhanced_monitoring ? 300 : 1800
            stat   = "Sum"
            unit   = "Count"
        }
    }

    metric_query {
        id = "dropout"

        metric {
            namespace = "CWAgent"
            dimensions = {
                InstanceId = aws_instance.vault_server[count.index].id
                interface  = "eth0"
            }
            metric_name = "net_drop_out"

            period = var.enhanced_monitoring ? 300 : 1800
            stat   = "Sum"
            unit   = "Count"
        }
    }

    metric_query {
        id = "drop"

        expression  = "dropin+dropout"
        label       = "net_drop"
        return_data = "true"
    }

    comparison_operator = "GreaterThanThreshold"
    threshold           = 100
    evaluation_periods  = var.enhanced_monitoring ? 5 : 3

    alarm_actions = [ aws_sns_topic.admin.arn ]
    ok_actions    = [ aws_sns_topic.admin.arn ]

    tags = {
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}

resource "aws_cloudwatch_metric_alarm" "vault_server_http5xx_hi" {
    count = var.vault_server_fqdn == null ? 0 : 1

    alarm_name        = "${var.project}-server-http5xx-hi"
    alarm_description = "HTTP 5xx codes (server errors) from the load balancer or target are high."

    metric_query {
        id = "lb_5xx"

        metric {
            namespace = "AWS/ApplicationELB"
            dimensions = {
                LoadBalancer = aws_lb.vault_server[count.index].arn_suffix
            }
            metric_name = "HTTPCode_ELB_5XX_Count"

            period = 60
            stat   = "Sum"
            unit   = "Count"
        }
    }

    metric_query {
        id = "target_5xx"

        metric {
            namespace = "AWS/ApplicationELB"
            dimensions = {
                LoadBalancer = aws_lb.vault_server[count.index].arn_suffix
            }
            metric_name = "HTTPCode_Target_5XX_Count"

            period = 60
            stat   = "Sum"
            unit   = "Count"
        }
    }

    metric_query {
        id = "total_5xx"

        expression  = "lb_5xx+target_5xx"
        label       = "HTTPCode_5XX_Count"
        return_data = "true"
    }

    comparison_operator = "GreaterThanThreshold"
    threshold           = 50
    evaluation_periods  = 5

    alarm_actions = [ aws_sns_topic.admin.arn ]
    ok_actions    = [ aws_sns_topic.admin.arn ]

    tags = {
        Service     = var.service
        Contact     = var.contact
        Environment = var.environment
        Project     = var.project
        NetID       = var.contact
    }
}