# WAF Managed Rules
resource "aws_wafv2_web_acl" "waf_acl" {
  name        = "web-acl"
  scope       = "REGIONAL"
  description = "Managed WAF ACL for Application Load Balancer"
  default_action {
    allow {}
  }

  visibility_config {
    sampled_requests_enabled    = true
    cloudwatch_metrics_enabled  = true
    metric_name                 = "webACL"
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      sampled_requests_enabled    = true
      cloudwatch_metrics_enabled  = true
      metric_name                 = "AWSCommonRuleSet"
    }
  }
}

# Attach WAF to ALB
resource "aws_wafv2_web_acl_association" "waf_acl_association" {
  resource_arn = aws_lb.app_lb.arn
  web_acl_arn  = aws_wafv2_web_acl.waf_acl.arn
}