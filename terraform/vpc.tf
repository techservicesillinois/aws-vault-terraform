# ===================================================================
# Data
# ===================================================================

data "aws_availability_zone" "public" {
    count = length(var.public_subnets)

    name = data.aws_subnet.public[count.index].availability_zone
}

data "aws_subnet" "public" {
    count = length(var.public_subnets)

    state = "available"

    tags = {
        Name = var.public_subnets[count.index]
    }
}

data "aws_vpc" "public" {
    id    = data.aws_subnet.public[0].vpc_id
    state = "available"
}

data "aws_subnet" "private" {
    count = length(var.private_subnets)

    state = "available"

    tags = {
        Name = var.private_subnets[count.index]
    }
}

data "aws_vpc" "private" {
    id    = data.aws_subnet.private[0].vpc_id
    state = "available"
}
