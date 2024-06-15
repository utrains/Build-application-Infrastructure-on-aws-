terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.36.0"
    }
  }
}

# Create a certificate request

resource "aws_acm_certificate" "cert_request" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  
  
  tags = {
    Name = var.domain_name
  }

  lifecycle {
    create_before_destroy = true
  }
}


# Create an record for the acm certificate request validation

resource "aws_route53_record" "cert_record" {
  zone_id         = aws_route53_zone.hosted_zone.zone_id
 name =  tolist(aws_acm_certificate.cert_request.domain_validation_options)[0].resource_record_name
  records = [tolist(aws_acm_certificate.cert_request.domain_validation_options)[0].resource_record_value]
  type = tolist(aws_acm_certificate.cert_request.domain_validation_options)[0].resource_record_type
  ttl             = var.ttl
  allow_overwrite = true
}

# Create an acm certificate request validation
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert_request.arn
  validation_record_fqdns = [aws_route53_record.cert_record.fqdn]
}
