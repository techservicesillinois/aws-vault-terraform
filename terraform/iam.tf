# ===================================================================
# Data
# ===================================================================

# ===================================================================
# Resources
# ===================================================================

resource "aws_kms_key" "vault" {
    description = "Protects all vault secure information."
    deletion_window_in_days = 7

    tags {
        Service = "${var.service}"
        Contact = "${var.contact}"
        DataClassification = "Sensitive"
        Environment = "${var.environment}"

        Project = "${var.project}"
        NetID = "${var.contact}"
    }
}
resource "aws_kms_alias" "vault" {
    name = "alias/${var.project}"
    target_key_id = "${aws_kms_key.vault.id}"
}
