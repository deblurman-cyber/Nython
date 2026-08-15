import net

class HttpServer:
    def init(self, port):
        self.port = port
        self.routes = {}
    def route(self, path, handler):
        self.routes[path] = handler
        return self
    def handle_request(self, request):
        var parts = request.split(" ")
        if len(parts) >= 2:
            var path = parts[1]
            if path in self.routes:
                return self.routes[path](parts[0], path)
        return "404"

var server = HttpServer(8080)
server.route("/", lambda m, p: "Home")
server.route("/api", lambda m, p: "API OK")
print server.handle_request("GET / HTTP/1.1")
print server.handle_request("GET /api HTTP/1.1")
print server.handle_request("GET /missing HTTP/1.1")
