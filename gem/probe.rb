require 'json-schema'
schema = {
  'type' => 'object',
  'required' => %w[status count name],
  'properties' => {
    'status' => { 'type' => 'string', 'enum' => %w[ok fail] },
    'count'  => { 'type' => 'integer', 'minimum' => 1 },
    'name'   => { 'type' => 'string', 'maxLength' => 3, 'pattern' => '^[a-z]+$' }
  }
}
cases = {
  'missing'  => { 'count' => 5, 'name' => 'ab' },
  'wrongtype'=> { 'status' => 1, 'count' => 'x', 'name' => 'ab' },
  'enum'     => { 'status' => 'nope', 'count' => 5, 'name' => 'ab' },
  'minimum'  => { 'status' => 'ok', 'count' => 0, 'name' => 'ab' },
  'maxlen'   => { 'status' => 'ok', 'count' => 5, 'name' => 'abcdef' },
  'pattern'  => { 'status' => 'ok', 'count' => 5, 'name' => 'AB' }
}
cases.each do |label, data|
  errs = JSON::Validator.fully_validate(schema, data)
  # strip the random schema fragment id so runs are comparable
  puts "#{label}: #{errs.map { |e| e.gsub(/[0-9a-f-]{36}/, 'UUID') }.sort.join(' | ')}"
end
