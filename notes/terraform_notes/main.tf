provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "myserver" {
    ami = "ami-066c4849e6b3a1e3d"
    instance_type = "t3.micro"
    tags = {
        Name = "webserver"
    }
}