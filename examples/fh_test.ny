import io
var f = open("/tmp/ny_fh.txt", "w")
print "handle:", f
file_write(f, "hello from file handle")
file_close(f)

var f2 = open("/tmp/ny_fh.txt", "r")
var content = file_read(f2)
file_close(f2)
print "content:", content
