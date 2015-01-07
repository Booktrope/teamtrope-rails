json.array!(@phases) do |phase|
  json.extract! phase, :id, :name, :color, :color_value, :icon, :verticial_order
  json.url phase_url(phase, format: :json)
end
