output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "workers_public_ips" {
  value = aws_instance.workers[*].public_ip
}

output "master_private_ip" {
  value = aws_instance.master.private_ip
}
