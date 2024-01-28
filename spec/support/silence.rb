def silence_stream(stream)
  old_stream = stream.dup
  stream.reopen(/mswin|mingw/.match?(RbConfig::CONFIG['host_os']) ? 'NUL:' : '/dev/null')
  stream.sync = true
  yield
ensure
  stream.reopen(old_stream)
  old_stream.close
end
