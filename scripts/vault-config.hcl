storage "raft" {
  path    = "/vault/data"
  node_id = "vault-1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

seal "transit" {
  address            = "http://vault-bootstrap:8200"
  token              = "dev-root-token"
  disable_renewal    = "false"
  key_name           = "autounseal"
  mount_path         = "transit/"
  tls_skip_verify    = "true"
}

api_addr = "http://vault:8200"
cluster_addr = "https://vault:8201"
ui = true
