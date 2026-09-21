output "ssh_connexion" {
  value = "ssh -i ${local_file.ssh_key.filename} ec2-user@${aws_instance.main-server.public_dns}"
}
output "JFROG_URL" {
  value = "http://${aws_instance.main-server.public_ip}:8082"
}

output "JFROG_CREDENTIALS" {
  value = "admin / password"
}

output "HASHICORP_VAULT_URL" {
  value = "http://${aws_instance.main-server.public_ip}:8200"
}

output "Vault_root_token" {
  value = "vaultkey.txt"
}
output "sonarqube_url" {
  value = "http://${aws_instance.main-server.public_ip}:9000"
}
output "sonarqube_credentials" {
  value = "admin / admin"
}
