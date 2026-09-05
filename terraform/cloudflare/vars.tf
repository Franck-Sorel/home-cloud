variable "tunnel_secret" {
  type      = string
  sensitive = true
  default   = "CHANGE_ME_generate_with_openssl_rand_-hex_32"
}