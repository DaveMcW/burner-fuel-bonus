data:extend{
  {
    type = "bool-setting",
    name = "burner-fuel-bonus-enable",
    setting_type = "runtime-global",
    default_value = true,
  },
  {
    type = "int-setting",
    name = "burner-fuel-bonus-refresh-rate",
    setting_type = "runtime-global",
    default_value = 3,
    minimum_value = 1,
    maximum_value = 1000,
  },
}
