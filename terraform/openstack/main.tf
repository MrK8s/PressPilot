terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "1.54.1"
    }
  }
}

provider "openstack" {}

resource "openstack_networking_network_v2" "wp_network" {
  name           = "wp_network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "wp_subnet" {
  name            = "wp_subnet"
  network_id      = openstack_networking_network_v2.wp_network.id
  cidr            = "192.168.199.0/24"
  ip_version      = 4
}

resource "openstack_networking_router_v2" "wp_router" {
  name                = "wp_router"
  external_network_id = var.external_network_id
}

resource "openstack_networking_router_interface_v2" "wp_router_interface" {
  router_id = openstack_networking_router_v2.wp_router.id
  subnet_id = openstack_networking_subnet_v2.wp_subnet.id
}

resource "openstack_networking_floatingip_v2" "wp_floating_ip" {
  pool = var.public_network
}

resource "openstack_compute_floatingip_associate_v2" "wp_fip_association" {
  floating_ip = openstack_networking_floatingip_v2.wp_floating_ip.address
  instance_id = openstack_compute_instance_v2.wp_instance.id
}

output "wordpress_floating_ip" {
    value = openstack_networking_floatingip_v2.wp_floating_ip.address
    description = "The floating IP of the WordPress service"
}

resource "openstack_compute_secgroup_v2" "wp_secgroup" {
  name        = "wp_secgroup"
  description = "security group for WordPress"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_instance_v2" "wp_instance" {
  name              = "wp_instance"
  image_name        = var.image_name
  flavor_name       = var.flavor_name
  security_groups   = [openstack_compute_secgroup_v2.wp_secgroup.name]
  key_pair = var.keypair_name
  network {
    uuid = openstack_networking_network_v2.wp_network.id
  }

user_data = <<-EOF
                #cloud-config
                write_files:
                - path: /etc/systemd/resolved.conf.d/dns_servers.conf
                  content: |
                    [Resolve]
                    DNS=8.8.8.8 8.8.4.4
                    FallbackDNS=8.8.8.8 8.8.4.4
                runcmd:
                  - systemctl restart systemd-resolved
                  - apt-get update && apt-get install -y docker.io
                  - systemctl start docker
                  - systemctl enable docker
                  - curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                  - chmod +x /usr/local/bin/docker-compose
                  - echo "${base64encode(file("${path.module}/docker-compose.yml"))}" | base64 --decode > /root/docker-compose.yml
                  - cd /root && docker-compose up -d
                EOF
}
