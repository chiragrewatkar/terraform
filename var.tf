
variable "aws_vpc" {
  type    = string
  default = "vpc"
}

variable "tags" {
  type    = string
  default = "main-vpc"
}

variable "public" {
  type = map(string)
  default = {
    "vpc"       = "10.0.0.0/16"
    "public-1"  = "10.0.1.0/24"
    "public-2"  = "10.0.2.0/24"
    "private-1" = "10.0.3.0/24"
    "private-2" = "10.0.4.0/24"
    "private-3" = "10.0.5.0/24"
    "route"     = "0.0.0.0/0"
  }
}