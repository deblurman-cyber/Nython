import io
write_file("test_output.txt", "Hello from Nython!\nLine 2\nLine 3")
print file_exists("test_output.txt")
var content = read_file("test_output.txt")
print content
print len(content)
