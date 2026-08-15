import io
import "examples/lib/io.ny"

# TextFile API
var tf = TextFile("/tmp/ny_tf.txt")
tf.write("Hello from TextFile!")
print tf.read()
print tf.size()
print tf.exists()

tf.append(" More data.")
print tf.read()

# Logger
var log = Logger("/tmp/ny_log.txt")
log.info("server started")
log.warn("low memory")
log.error("disk full")
var entries = log.lines()
print "log entries:", len(entries)
for entry in entries:
    print entry
