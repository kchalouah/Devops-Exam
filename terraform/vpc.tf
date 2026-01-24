# Use Default VPC due to AWS Academy Learner Lab restrictions
resource "aws_default_vpc" "default" {}

# Use Default Subnet
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}

data "aws_subnet" "selected" {
  id = data.aws_subnets.default.ids[0]
}
