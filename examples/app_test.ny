import io
write("/tmp/ny_app.txt", "line1")
file_append("/tmp/ny_app.txt", "line2")
file_append("/tmp/ny_app.txt", "line3")
var lines = readlines("/tmp/ny_app.txt")
print lines
print len(lines)
