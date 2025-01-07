#Route 53 A Record for NodePort service using the Elastic IP
data "aws_route53_zone" "zone" {
  name = "cultivatedcode.co"
}

resource "aws_route53_record" "nodeport_service" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.microk8s_eip.public_ip]
}


resource "aws_route53_record" "www_nodeport_service" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.microk8s_eip.public_ip]
}
