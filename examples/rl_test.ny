import io
var f = open("/tmp/ny_multi.txt", "r")
print file_readline(f)
print file_readline(f)
print file_readline(f)
var done = file_readline(f)
print "eof:", done
file_close(f)
