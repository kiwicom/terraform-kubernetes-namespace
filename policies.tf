resource "kubernetes_priority_class" "kw_system_priority" {
  count          = var.name == "system" ? 1 : 0
  value          = 1000000000
  global_default = false
  description    = "This priority class should be used for kw system applications only"
  metadata {
    name        = "kw-system-priority"
  }
}
