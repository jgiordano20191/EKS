data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.test-cluster.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon
}

# launch workers
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  test-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.test-cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.test-cluster.certificate_authority[0].data}' '${var.cluster-name}'
USERDATA

}

resource "aws_launch_configuration" "test" {
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.test-node.name
  image_id = data.aws_ami.eks-worker.id
  instance_type = "t2.medium"
  name_prefix = "terraform-eks-test"
  security_groups = [aws_security_group.test-node-wrkgrp.id]
  user_data_base64 = base64encode(local.test-node-userdata)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "test" {
  desired_capacity = 2
  launch_configuration = aws_launch_configuration.test.id
  max_size = 5
  min_size = 2
  name = "terraform-eks-test"

  vpc_zone_identifier = module.vpc.public_subnets

  tag {
    key = "Name"
    value = "terraform-eks-test"
    propagate_at_launch = true
  }

  tag {
    key = "kubernetes.io/cluster/${var.cluster-name}"
    value = "owned"
    propagate_at_launch = true
  }
}
