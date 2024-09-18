provider "aws" {
  region = "ap-south-1"
}

variable "ec2_private_key" {
  type      = string
  sensitive = true
}

resource "aws_instance" "medusa_ec2" {
  ami                    = "ami-0c2af51e265bd5e0e"
  instance_type          = "t2.micro"
  key_name               = "Kt5"
  vpc_security_group_ids = ["sg-0da7a1cd89d513cb5"]

  tags = {
    Name = "MedusaEC2"
  }

  provisioner "file" {
    source      = "install.sh"
    destination = "/home/ubuntu/install.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.ec2_private_key
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/install.sh",
      "/home/ubuntu/install.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.ec2_private_key
      host        = self.public_ip
    }

    timeout = "30m"
  }
}

output "ec2_public_ip" {
  value = aws_instance.medusa_ec2.public_ip
}
