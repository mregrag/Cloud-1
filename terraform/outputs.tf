output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.app_server.public_dns
}

output "instance_ami" {
  description = "AMI used by the EC2 instance"
  value       = aws_instance.app_server.ami
}

output "instance_type" {
  description = "EC2 instance type"
  value       = aws_instance.app_server.instance_type
}
