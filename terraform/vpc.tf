# ===================================================================
# Data
# ===================================================================

data "aws_subnet" "public" {
    count = "${length(var.public_subnets)}"

    state = "available"

    tags {
        Name = "${element(var.public_subnets, count.index)}"
    }
}
data "aws_vpc" "public" {
    id = "${data.aws_subnet.public.0.vpc_id}"
    state = "available"
}
