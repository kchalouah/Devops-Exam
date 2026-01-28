# Get latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Master Node
resource "aws_instance" "master" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnet.selected.id
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  root_block_device {
    volume_size = 16
  }

  tags = {
    Name = "k8s-master"
  }
}

# Worker Nodes
resource "aws_instance" "workers" {
  count         = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnet.selected.id
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  root_block_device {
    volume_size = 16
  }

  tags = {
    Name = "k8s-worker-${count.index + 1}"
  }
}
