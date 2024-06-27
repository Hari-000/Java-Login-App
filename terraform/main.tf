
##VPC's 

resource "aws_vpc" "bastion-host" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "bastion-host-vpc"
  }
}

resource "aws_vpc" "app-servers" {
  cidr_block = "172.32.0.0/16"
  tags = {
    Name = "application-servers"
  }
}


##Subnets 

resource "aws_subnet" "bastion-subnet" {
  vpc_id                  = aws_vpc.bastion-host.id
  cidr_block              = "192.168.0.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "pub-subnet-bastion"
  }
}

resource "aws_subnet" "public-2a" {
  vpc_id                  = aws_vpc.app-servers.id
  cidr_block              = "172.32.0.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "pub-subnet2a"
  }
}

resource "aws_subnet" "public-2b" {
  vpc_id                  = aws_vpc.app-servers.id
  cidr_block              = "172.32.1.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "pub-subnet2b"
  }
}

resource "aws_subnet" "private-2a" {
  vpc_id            = aws_vpc.app-servers.id
  cidr_block        = "172.32.2.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "pvt-subnet2a"
  }
}

resource "aws_subnet" "private-2b" {
  vpc_id            = aws_vpc.app-servers.id
  cidr_block        = "172.32.3.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "pvt-subnet2b"
  }
}

## Internet gateway
resource "aws_internet_gateway" "igw-vpc1" {
  vpc_id = aws_vpc.bastion-host.id

  tags = {
    Name = "igw-vpc1"
  }
}

resource "aws_internet_gateway" "igw-vpc2" {
  vpc_id = aws_vpc.app-servers.id

  tags = {
    Name = "igw-vpc2"
  }
}

##route-table

resource "aws_route_table" "vpc1-rt" {
  vpc_id = aws_vpc.bastion-host.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-vpc1.id
  }

  route {
    cidr_block = aws_vpc.app-servers.cidr_block
    gateway_id = aws_ec2_transit_gateway.tg.id
  }

  tags = {
    Name = "vpc1-rt"
  }
}

resource "aws_route_table_association" "vpc1-rta" {
  subnet_id      = aws_subnet.bastion-subnet.id
  route_table_id = aws_route_table.vpc1-rt.id
}


resource "aws_route_table" "vpc2-rt" {
  vpc_id = aws_vpc.app-servers.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-vpc2.id
  }

  route {
    cidr_block = aws_vpc.bastion-host.cidr_block
    gateway_id = aws_ec2_transit_gateway.tg.id
  }

  tags = {
    Name = "vpc2-rt"
  }
}

resource "aws_route" "route-tgw-vpc2" {
  route_table_id            = "rtb-01f44f2a4f49edad1"
  destination_cidr_block    = aws_vpc.bastion-host.cidr_block
  gateway_id = aws_ec2_transit_gateway.tg.id
}

/*resource "aws_route_table_association" "vpc2-rta1" {
  subnet_id      = aws_subnet.public-2a.id
  route_table_id = aws_route_table.vpc2-rt.id

}*/

resource "aws_route_table_association" "vpc2-rta2" {
  subnet_id      = aws_subnet.public-2b.id
  route_table_id = aws_route_table.vpc2-rt.id

}

## NAT gateway

resource "aws_eip" "e-ip" {
  domain = "vpc"

}

resource "aws_nat_gateway" "nat-vpc2" {
  allocation_id = aws_eip.e-ip.id
  subnet_id     = aws_subnet.public-2a.id

  tags = {
    Name = "gw NAT-vpc2"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw-vpc2]
}

resource "aws_route_table" "rt-vpc2-nat" {
  vpc_id = aws_vpc.app-servers.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-vpc2.id
  }

  tags = {
    Name = "rt-vpc2-nat"
  }

}

resource "aws_route_table_association" "rt-vpc2-nat" {
  subnet_id      = aws_subnet.public-2a.id
  route_table_id = aws_route_table.rt-vpc2-nat.id

}

## transit gateway

resource "aws_ec2_transit_gateway" "tg" {
  description = "transit gateway to connect 2 vpc's"

  tags = {
    Name = "transit-gw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-vpc-app-attachement" {
  subnet_ids         = [aws_subnet.private-2a.id, aws_subnet.private-2b.id]
  transit_gateway_id = aws_ec2_transit_gateway.tg.id
  vpc_id             = aws_vpc.app-servers.id

  tags = {
    Name = "tgw-app-vpc-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-vpc-bastion-attachement" {
  subnet_ids         = [aws_subnet.bastion-subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tg.id
  vpc_id             = aws_vpc.bastion-host.id

  tags = {
    Name = "tgw-bastion-vpc-attachement"
  }
}

/*resource "aws_route" "bastion-app" {
  route_table_id         = aws_route_table.vpc1-rt.id
  destination_cidr_block = aws_vpc.app-servers.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tg.id
}

resource "aws_route" "app-bastion" {
  route_table_id         = aws_route_table.vpc2-rt.id
  destination_cidr_block = aws_vpc.bastion-host.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.tg.id
}*/

##bastion instance
resource "aws_instance" "bastion" {
  ami                         = "ami-0a9cbae439fc918db"
  instance_type               = "t2.micro"
  associate_public_ip_address = "true"
  subnet_id                   = aws_subnet.bastion-subnet.id
  vpc_security_group_ids      = [aws_security_group.bastion-sg.id]
  key_name                    = "ohio-key"

  tags = {
    Name = "Bastion-host"
  }
}

resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  domain   = "vpc"
}

##security group

resource "aws_security_group" "bastion-sg" {
  name        = "bastion-sg"
  description = "sg for bastion"
  vpc_id      = aws_vpc.bastion-host.id

  tags = {
    Name = "bastion-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_shh" {
  security_group_id = aws_security_group.bastion-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.bastion-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.bastion-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound" {
  security_group_id = aws_security_group.bastion-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_security_group" "maven-sg" {
  name        = "maven-sg"
  description = "sg for maven"
  vpc_id      = aws_vpc.app-servers.id

  tags = {
    Name = "maven-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_shh_maven" {
  security_group_id = aws_security_group.maven-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_maven-sg" {
  security_group_id = aws_security_group.maven-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


## maven ec2 instance

resource "aws_instance" "maven" {
  ami                         = "ami-0b141ef9655809443"
  instance_type               = "t2.micro"
  associate_public_ip_address = "true"
  subnet_id                   = aws_subnet.private-2a.id
  key_name                    = "ohio-key"
  vpc_security_group_ids      = [aws_security_group.maven-sg.id]

  tags = {
    Name = "maven"
  }
}
